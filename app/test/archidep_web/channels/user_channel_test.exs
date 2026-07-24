defmodule ArchiDepWeb.Channels.UserChannelTest do
  use ArchiDepWeb.Support.ChannelCase, async: true

  alias ArchiDep.Course
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentDeleted
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Course.UseCases.ReadStudents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.UseCases.ReadServers
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.ClientSessionData

  # The channel is server-to-client push only: its observable contract is the
  # `join` reply plus the `"session"` / `"cloudServerData"` events. The initial
  # session data is the join *reply*; `send_updated_data/1` only *pushes*
  # `"session"` when the data changes from what was last sent, so a fresh join
  # pushes `"cloudServerData"` but not `"session"`. PubSub is real, so a
  # `handle_info` clause is driven by broadcasting on the topic the channel
  # subscribed to at join time.

  @now ~U[2026-06-19 12:00:00Z]

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    stub_read_models()
    :ok
  end

  describe "join/3" do
    test "replies with the session data and pushes the cloud server data for a root user" do
      auth = root_auth()
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [] end)

      {:ok, reply, _socket} = join_channel(auth)

      assert reply == session_data(auth, nil)
      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
      refute_push "session", _
    end

    test "replies with the session data and pushes the cloud server data for a student" do
      auth = student_auth()
      class = CourseFactory.build(:class, servers_enabled: true)
      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")
      expect_student_join(auth, student, [])

      {:ok, reply, _socket} = join_channel(auth)

      assert reply == session_data(auth, student_payload(student))
      assert_push "cloudServerData", cloud
      assert cloud == %{student: student_payload(student), server: nil, serversEnabled: true}
      refute_push "session", _
    end

    test "pushes the single active server in the cloud server data" do
      auth = root_auth()
      server = active_server(auth.principal_id, name: "web-01", username: "ops")
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [ServerView.from(server)] end)

      {:ok, reply, _socket} = join_channel(auth)

      assert reply == session_data(auth, nil)
      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: server_payload(server), serversEnabled: false}
      refute_push "session", _
    end

    test "filters out inactive servers from the cloud server data" do
      auth = root_auth()
      inactive = Map.put(active_server(auth.principal_id), :active, false)

      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [ServerView.from(inactive)] end)

      {:ok, _reply, _socket} = join_channel(auth)

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
    end
  end

  describe "handle_info/2 for class events" do
    test "refreshes the class and republishes the cloud server data on a class update" do
      auth = student_auth()
      esp = CourseFactory.build(:expected_server_properties)

      class =
        CourseFactory.build(:class,
          version: 1,
          active: true,
          start_date: nil,
          end_date: nil,
          servers_enabled: false,
          expected_server_properties: esp
        )

      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")
      expect_student_join(auth, student, [])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: student_payload(student), server: nil, serversEnabled: false}

      updated_class = %{class | version: 2, servers_enabled: true}

      Course.PubSub.publish_class_updated(
        updated_class,
        ClassUpdated.new(updated_class),
        EventsFactory.build(:event_reference, version: updated_class.version)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: student_payload(student), server: nil, serversEnabled: true}
      refute_push "session", _
    end

    test "drops the student and the cloud server data on a class deletion" do
      auth = student_auth()
      class = CourseFactory.build(:class, servers_enabled: true)
      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")
      expect_student_join(auth, student, [])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: student_payload(student), server: nil, serversEnabled: true}

      Course.PubSub.publish_class_deleted(
        ClassDeleted.new(class),
        EventsFactory.build(:event_reference)
      )

      assert_push "session", session
      assert session == Map.from_struct(session_data(auth, nil))
      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
    end

    test "drops the class's active servers on a class deletion" do
      auth = student_auth()
      class = CourseFactory.build(:class, servers_enabled: true)
      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")

      server =
        student_active_server(auth.principal_id, class, student, name: "web-01", username: "ops")

      expect_student_join(auth, student, [server])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial

      assert initial == %{
               student: student_payload(student),
               server: server_payload(server),
               serversEnabled: true
             }

      Course.PubSub.publish_class_deleted(
        ClassDeleted.new(class),
        EventsFactory.build(:event_reference)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
    end
  end

  describe "handle_info/2 for student events" do
    test "refreshes the student and republishes both messages on a displayed-field update" do
      auth = student_auth()
      class = CourseFactory.build(:class, version: 5, servers_enabled: false)
      user = CourseFactory.build(:user)

      student =
        student_in(class,
          version: 1,
          user: user,
          user_id: user.id,
          username: "jdoe",
          username_confirmed: true,
          domain: "jdoe.ch",
          servers_enabled: false
        )

      expect_student_join(auth, student, [])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: student_payload(student), server: nil, serversEnabled: false}

      updated = %{
        student
        | version: 2,
          username: "jane",
          domain: "jane.ch"
      }

      Course.PubSub.publish_student_updated(
        updated,
        StudentUpdated.new(updated),
        EventsFactory.build(:event_reference,
          version: updated.version,
          occurred_at: updated.updated_at
        )
      )

      assert_push "session", session
      assert session == Map.from_struct(session_data(auth, student_payload(updated)))
      assert_push "cloudServerData", cloud
      assert cloud == %{student: student_payload(updated), server: nil, serversEnabled: false}
    end

    test "pushes nothing when a student update changes no displayed field" do
      auth = student_auth()
      class = CourseFactory.build(:class, version: 5, servers_enabled: false)
      user = CourseFactory.build(:user)

      student =
        student_in(class,
          version: 1,
          user: user,
          user_id: user.id,
          username: "jdoe",
          username_confirmed: true,
          domain: "jdoe.ch",
          servers_enabled: false,
          academic_class: "A1"
        )

      expect_student_join(auth, student, [])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: student_payload(student), server: nil, serversEnabled: false}

      updated = %{student | version: 2, academic_class: "B2"}

      Course.PubSub.publish_student_updated(
        updated,
        StudentUpdated.new(updated),
        EventsFactory.build(:event_reference,
          version: updated.version,
          occurred_at: updated.updated_at
        )
      )

      refute_push "session", _
      refute_push "cloudServerData", _
    end

    test "drops the student and the cloud server data on a student deletion" do
      auth = student_auth()
      class = CourseFactory.build(:class, servers_enabled: true)
      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")
      expect_student_join(auth, student, [])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: student_payload(student), server: nil, serversEnabled: true}

      Course.PubSub.publish_student_deleted(
        StudentDeleted.new(student),
        EventsFactory.build(:event_reference)
      )

      assert_push "session", session
      assert session == Map.from_struct(session_data(auth, nil))
      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
    end

    test "drops the student's active servers on a student deletion" do
      auth = student_auth()
      class = CourseFactory.build(:class, servers_enabled: true)
      student = student_in(class, username: "jdoe", username_confirmed: true, domain: "jdoe.ch")

      server =
        student_active_server(auth.principal_id, class, student, name: "web-01", username: "ops")

      expect_student_join(auth, student, [server])
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial

      assert initial == %{
               student: student_payload(student),
               server: server_payload(server),
               serversEnabled: true
             }

      Course.PubSub.publish_student_deleted(
        StudentDeleted.new(student),
        EventsFactory.build(:event_reference)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
    end
  end

  describe "handle_info/2 for server events" do
    test "adds a newly created active server to the cloud server data" do
      auth = root_auth()
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [] end)
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: nil, server: nil, serversEnabled: false}

      server = active_server(auth.principal_id, name: "web-01", username: "ops")
      server_id = server.id

      expect(Servers.ContextMock, :fetch_server, 1, fn ^auth, ^server_id ->
        {:ok, ServerView.from(server)}
      end)

      Servers.PubSub.publish_server_created(
        ServerCreated.new(server),
        EventsFactory.build(:event_reference)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: server_payload(server), serversEnabled: false}
      refute_push "session", _
    end

    test "removes a server that an update makes inactive from the cloud server data" do
      auth = root_auth()
      server = active_server(auth.principal_id, name: "web-01", username: "ops")
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [ServerView.from(server)] end)
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: nil, server: server_payload(server), serversEnabled: false}

      deactivated = %{server | active: false, version: server.version + 1}

      Servers.PubSub.publish_server_updated(
        ServerUpdated.new(deactivated),
        EventsFactory.build(:event_reference, version: deactivated.version)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
      refute_push "session", _
    end

    test "replaces a server that stays active in the cloud server data" do
      auth = root_auth()
      server = active_server(auth.principal_id, name: "web-01", username: "ops")
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [ServerView.from(server)] end)
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: nil, server: server_payload(server), serversEnabled: false}

      updated = %{server | name: "web-02", version: server.version + 1}

      Servers.PubSub.publish_server_updated(
        ServerUpdated.new(updated),
        EventsFactory.build(:event_reference, version: updated.version)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: server_payload(updated), serversEnabled: false}
      refute_push "session", _
    end

    test "removes a deleted server from the cloud server data" do
      auth = root_auth()
      server = active_server(auth.principal_id, name: "web-01", username: "ops")
      expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth -> [ServerView.from(server)] end)
      {:ok, _reply, _socket} = join_channel(auth)
      assert_push "cloudServerData", initial
      assert initial == %{student: nil, server: server_payload(server), serversEnabled: false}

      Servers.PubSub.publish_server_deleted(
        ServerDeleted.new(server),
        EventsFactory.build(:event_reference)
      )

      assert_push "cloudServerData", cloud
      assert cloud == %{student: nil, server: nil, serversEnabled: false}
      refute_push "session", _
    end
  end

  defp root_auth, do: Factory.build(:authentication, root: true, impersonated_id: nil)
  defp student_auth, do: Factory.build(:authentication, root: false, impersonated_id: nil)

  defp join_channel(auth) do
    UserSocket
    |> socket("auth:#{auth.principal_id}", %{auth: auth})
    |> subscribe_and_join(UserChannel, "me")
  end

  defp expect_student_join(auth, student, servers) do
    expect(Course.ContextMock, :fetch_authenticated_student, 1, fn ^auth ->
      {:ok, StudentView.from(student)}
    end)

    expect(Servers.ContextMock, :list_my_servers, 1, fn ^auth ->
      Enum.map(servers, &ServerView.from/1)
    end)
  end

  # The channel keeps the student (with its nested class) and the owner's server
  # list live through the Course and Servers boundaries; route the subscriptions
  # and reconcilers to the real use cases so a real broadcast drives the channel
  # and exercises the real merge logic (fetches go through the mocked boundary).
  defp stub_read_models do
    stub(Course.ContextMock, :subscribe_student_detail, &ReadStudents.subscribe_student_detail/1)
    stub(Course.ContextMock, :refresh_student_detail, &ReadStudents.refresh_student_detail/2)
    stub(Servers.ContextMock, :subscribe_my_servers, &ReadServers.subscribe_my_servers/1)
    stub(Servers.ContextMock, :refresh_my_servers, &ReadServers.refresh_my_servers/3)
    :ok
  end

  defp student_in(class, attrs) do
    CourseFactory.build(
      :student,
      Keyword.merge(
        [class: class, class_id: class.id, user: nil, user_id: nil, servers_enabled: false],
        attrs
      )
    )
  end

  defp student_active_server(owner_id, class, student, attrs) do
    group =
      ServersFactory.build(:server_group,
        id: class.id,
        active: true,
        start_date: nil,
        end_date: nil
      )

    group_member =
      ServersFactory.build(:server_group_member,
        id: student.id,
        active: true,
        group: group,
        group_id: group.id
      )

    owner =
      ServersFactory.build(:server_owner,
        id: owner_id,
        root: false,
        active: true,
        group_member: group_member,
        group_member_id: group_member.id
      )

    ServersFactory.build(
      :server,
      Keyword.merge(
        [
          active: true,
          owner_id: owner_id,
          owner: owner,
          group_id: group.id,
          group: group,
          ip_address: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: 32}
        ],
        attrs
      )
    )
  end

  defp active_server(owner_id, attrs \\ []) do
    group = ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil)

    owner =
      ServersFactory.build(:server_owner,
        id: owner_id,
        root: true,
        active: true,
        group_member: nil
      )

    ServersFactory.build(
      :server,
      Keyword.merge(
        [
          active: true,
          owner_id: owner_id,
          owner: owner,
          group_id: group.id,
          group: group,
          ip_address: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: 32}
        ],
        attrs
      )
    )
  end

  defp session_data(auth, student_payload),
    do: %ClientSessionData{
      username: auth.username,
      root: auth.root,
      impersonating: false,
      sessionId: auth.session_id,
      sessionExpiresAt: DateTime.to_iso8601(auth.session_expires_at),
      student: student_payload
    }

  defp student_payload(student),
    do: %{
      username: student.username,
      usernameConfirmed: student.username_confirmed,
      domain: student.domain
    }

  defp server_payload(server),
    do: %{
      name: server.name,
      username: server.username,
      ipAddress: "10.0.0.42",
      url: "/servers/#{server.id}"
    }
end
