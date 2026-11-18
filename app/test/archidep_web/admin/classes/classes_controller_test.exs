defmodule ArchiDepWeb.Admin.Classes.ClassesControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Servers
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

  @now ~U[2026-11-18 14:02:17.000000Z]

  setup :verify_on_exit!

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "GET /admin/classes/:id/export/:format" do
    setup :register_and_log_in_root

    test "download the emails of the students matching the filters without reading servers", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Demo Class")
      class_view = ClassView.from(class)

      students = [
        CourseFactory.build(:student_view, academic_class: "INF-1", email: "alice@heig-vd.ch"),
        CourseFactory.build(:student_view, academic_class: "INF-2", email: "bob@heig-vd.ch"),
        CourseFactory.build(:student_view, academic_class: "INF-1", email: "carol@heig-vd.ch")
      ]

      expect_class(auth, class_view)
      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class_view -> students end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/export/emails?academic_class=INF-1")

      assert download(conn) == %{
               status: 200,
               content_type: ["text/plain; charset=utf-8"],
               content_disposition: ["attachment; filename=\"Demo Class - emails.txt\""],
               body: "alice@heig-vd.ch\ncarol@heig-vd.ch\n"
             }
    end

    test "download the CSV of the students with their active servers", %{conn: conn, auth: auth} do
      class = CourseFactory.build(:class, name: "Demo Class")
      class_view = ClassView.from(class)

      with_server =
        CourseFactory.build(:student_view,
          name: "Alice Cidre",
          academic_class: "CS-1",
          email: "alice@example.com",
          domain: "archidep1.ch"
        )

      without_server =
        CourseFactory.build(:student_view,
          name: "Bob Dupont",
          academic_class: nil,
          email: "bob@example.com",
          domain: "archidep2.ch"
        )

      server =
        ServersFactory.build(:server_view,
          username: "user42",
          ip_address: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: 32},
          owner: ServersFactory.build(:server_owner, root: false, group_member_id: with_server.id)
        )

      expect_class(auth, class_view)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class_view ->
        [with_server, without_server]
      end)

      expect_active_servers(auth, class.id, {:ok, [server]})

      conn = get(conn, ~p"/admin/classes/#{class.id}/export/csv")

      assert download(conn) == %{
               status: 200,
               content_type: ["text/csv; charset=utf-8"],
               content_disposition: ["attachment; filename=\"Demo Class.csv\""],
               body:
                 "name,class,email,ip,username,domain,comments\n" <>
                   "Alice Cidre,CS-1,alice@example.com,10.0.0.42,user42,archidep1.ch,\n" <>
                   "Bob Dupont,,bob@example.com,,,archidep2.ch,\n"
             }
    end

    test "download the SSH exercise inventory with the passwords in the clear", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Demo Class")
      class_view = ClassView.from(class)

      student =
        CourseFactory.build(:student_view, username: "alice", ssh_exercise_password: "a-secret")

      expect_class(auth, class_view)
      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class_view -> [student] end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/export/ssh-exercise-inventory")

      assert download(conn, &Jason.decode!/1) == %{
               status: 200,
               content_type: ["application/json; charset=utf-8"],
               content_disposition: ["attachment; filename=\"inventory.yml\""],
               body: %{"students" => [%{"username" => "alice", "password" => "a-secret"}]}
             }
    end

    test "download the DNS records of the filtered students who have an active server", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Demo Class")
      class_view = ClassView.from(class)

      registered =
        CourseFactory.build(:student_view, username: "alice", user_id: UUID.generate())

      unregistered =
        CourseFactory.build(:student_view, username: "bob", domain: "archidep1.ch", user_id: nil)

      unregistered_server =
        ServersFactory.build(:server_view,
          ip_address: %Postgrex.INET{address: {10, 0, 0, 2}, netmask: 32},
          owner:
            ServersFactory.build(:server_owner, root: false, group_member_id: unregistered.id)
        )

      registered_server =
        ServersFactory.build(:server_view,
          owner: ServersFactory.build(:server_owner, root: false, group_member_id: registered.id)
        )

      expect_class(auth, class_view)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class_view ->
        [registered, unregistered]
      end)

      expect_active_servers(auth, class.id, {:ok, [registered_server, unregistered_server]})

      conn = get(conn, ~p"/admin/classes/#{class.id}/export/dns-records?registered=no")

      assert download(conn) == %{
               status: 200,
               content_type: ["text/plain; charset=utf-8"],
               content_disposition: ["attachment; filename=\"Demo Class - DNS records.txt\""],
               body: """
               ; BEGIN DNS records of the servers of the ArchiDep students of class Demo Class, generated 2026-11-18 14:02 UTC
               ; archidep1.ch
               bob 300 IN A 10.0.0.2
               *.bob 300 IN A 10.0.0.2
               ; END DNS records of the servers of the ArchiDep students of class Demo Class
               """
             }
    end

    test "reject an unknown format", %{conn: conn} do
      conn = get(conn, ~p"/admin/classes/#{UUID.generate()}/export/unknown")

      assert response(conn, 404) == "Not Found"
    end

    test "reject the download when the server group cannot be read", %{conn: conn, auth: auth} do
      class = CourseFactory.build(:class)
      class_view = ClassView.from(class)

      expect_class(auth, class_view)
      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class_view -> [] end)
      expect_active_servers(auth, class.id, {:error, :server_group_not_found})

      conn = get(conn, ~p"/admin/classes/#{class.id}/export/known-hosts")

      assert response(conn, 401) == "Unauthorized"
    end
  end

  test "reject the download for an anonymous user", %{conn: conn} do
    class_id = UUID.generate()

    expect(Course.ContextMock, :fetch_class, 1, fn nil, ^class_id ->
      {:error, :class_not_found}
    end)

    conn = get(conn, ~p"/admin/classes/#{class_id}/export/emails")

    assert response(conn, 401) == "Unauthorized"
  end

  defp expect_class(auth, class_view) do
    class_id = class_view.id
    expect(Course.ContextMock, :fetch_class, 1, fn ^auth, ^class_id -> {:ok, class_view} end)
  end

  defp expect_active_servers(auth, class_id, result),
    do:
      expect(Servers.ContextMock, :list_active_servers_in_group, 1, fn ^auth, ^class_id ->
        result
      end)

  defp download(conn, body_fun \\ & &1) do
    %{
      status: conn.status,
      content_type: get_resp_header(conn, "content-type"),
      content_disposition: get_resp_header(conn, "content-disposition"),
      body: body_fun.(response(conn, conn.status))
    }
  end
end
