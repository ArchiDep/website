defmodule ArchiDep.Servers.Schemas.ServerGroupMemberTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]

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
end
