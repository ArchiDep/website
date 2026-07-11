defmodule ArchiDep.Servers.Schemas.ServerGroupMemberTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

  describe "list_members_in_server_group/1" do
    test "lists every member of the group by name, with its owner graph preloaded" do
      %{class: class, student: bob} =
        ServersTestHelpers.register_group_member(@now, student: [name: "Bob"])

      %{student: alice} =
        ServersTestHelpers.register_group_member(@now, class: class, student: [name: "Alice"])

      assert ServerGroupMember.list_members_in_server_group(class.id) ==
               [deep_member_view(alice.id), deep_member_view(bob.id)]
    end

    test "returns an empty list when the group has no member" do
      class = CourseFactory.insert(:class, now: @now)

      assert ServerGroupMember.list_members_in_server_group(class.id) == []
    end
  end

  describe "fetch_server_group_member_for_user_account_id/1" do
    test "fetches the group member owning the given user account" do
      %{owner: owner, student: student} = ServersTestHelpers.register_group_member(@now)

      assert ServerGroupMember.fetch_server_group_member_for_user_account_id(owner.id) ==
               {:ok, shallow_member_view(student.id)}
    end

    test "returns an error when no group member owns the given user account" do
      assert ServerGroupMember.fetch_server_group_member_for_user_account_id(UUID.generate()) ==
               {:error, :server_group_member_not_found}
    end
  end

  describe "fetch_server_group_member/1" do
    test "fetches a group member with its owner graph preloaded by id" do
      %{student: student} = ServersTestHelpers.register_group_member(@now)

      assert ServerGroupMember.fetch_server_group_member(student.id) ==
               {:ok, deep_member_view(student.id)}
    end

    test "returns an error when no group member has the given id" do
      assert ServerGroupMember.fetch_server_group_member(UUID.generate()) ==
               {:error, :server_group_member_not_found}
    end
  end

  # A member read back exactly as `list_members_in_server_group/1` and
  # `fetch_server_group_member/1` return it: the `students` row with its group
  # and its owner (and that owner's own group member and group) preloaded.
  defp deep_member_view(id),
    do:
      ServerGroupMember
      |> Repo.get!(id)
      |> Repo.preload([:group, owner: [group_member: :group]])

  # A member read back as `fetch_server_group_member_for_user_account_id/1`
  # returns it: the group and owner preloaded, but nothing under the owner.
  defp shallow_member_view(id),
    do:
      ServerGroupMember
      |> Repo.get!(id)
      |> Repo.preload([:group, :owner])

  describe "refresh!/2" do
    test "merges an incoming student broadcast one version ahead into the cached member" do
      %{student: student} = ServersTestHelpers.register_group_member(@now)
      {:ok, member} = ServerGroupMember.fetch_server_group_member(student.id)
      {:ok, updated_student} = Student.fetch_student(student.id)

      # The broadcast carries the next version and diverges from the persisted
      # row on every merged field, so the assertion can only pass if the
      # in-memory merge ran: the catch-all fallback would re-fetch and return
      # the persisted values instead. (The cross-context student clause does not
      # propagate the username, so it is left unchanged here.)
      updated = %{
        updated_student
        | name: "Renamed member",
          domain: "renamed.archidep.ch",
          active: not member.active,
          servers_enabled: not member.servers_enabled,
          version: member.version + 1,
          updated_at: @later
      }

      assert ServerGroupMember.refresh!(member, updated) == %{
               member
               | name: "Renamed member",
                 domain: "renamed.archidep.ch",
                 active: updated.active,
                 servers_enabled: updated.servers_enabled,
                 version: member.version + 1,
                 updated_at: @later
             }
    end

    test "ignores a student broadcast at or below the cached version" do
      %{student: student} = ServersTestHelpers.register_group_member(@now)
      {:ok, member} = ServerGroupMember.fetch_server_group_member(student.id)
      {:ok, updated_student} = Student.fetch_student(student.id)

      stale = %{updated_student | name: "Ignored", version: member.version, updated_at: @later}

      assert ServerGroupMember.refresh!(member, stale) == member
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      %{student: student} = ServersTestHelpers.register_group_member(@now)
      {:ok, member} = ServerGroupMember.fetch_server_group_member(student.id)
      {:ok, updated_student} = Student.fetch_student(student.id)

      {1, nil} =
        Repo.update_all(
          from(m in ServerGroupMember, where: m.id == ^member.id),
          set: [name: "Persisted rename", version: member.version + 2, updated_at: @later]
        )

      {:ok, fresh} = ServerGroupMember.fetch_server_group_member(member.id)
      refute fresh == member

      gapped = %{
        updated_student
        | name: "Ignored",
          version: member.version + 2,
          updated_at: @later
      }

      assert ServerGroupMember.refresh!(member, gapped) == fresh
    end
  end
end
