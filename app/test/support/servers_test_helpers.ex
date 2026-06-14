defmodule ArchiDep.Support.ServersTestHelpers do
  @moduledoc """
  Multi-entity orchestration for the servers context. The server-context schemas
  are read-views over other contexts' tables (`ServerGroup` over `classes`,
  `ServerOwner` over `user_accounts`, `ServerGroupMember` over `students`), so a
  persisted server's owner/group graph is several interdependent inserts plus
  the bidirectional link between a user account and its student.
  """

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import ArchiDep.Support.DataCase, only: [not_loaded: 2]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Authentication
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

  @doc """
  Persists an active root user account at the given instant and builds a
  matching root authentication. The server use cases load the authenticated
  owner (`ServerOwner.fetch_authenticated/1`) before any root short-circuit, so
  the row must exist even for root callers. Returns `{auth, user_account}`.
  """
  @spec register_root(DateTime.t(), Keyword.t()) :: {Authentication.t(), UserAccount.t()}
  def register_root(now, overrides \\ []) do
    user_account =
      AccountsFactory.insert(
        :user_account,
        Keyword.merge([root: true, active: true, switch_edu_id: nil, now: now], overrides)
      )

    auth = Factory.build(:authentication, principal_id: user_account.id, root: true)

    {auth, user_account}
  end

  @doc """
  Persists the full graph a non-root server owner needs: an active class (the
  server group), an active student in it (the group member) with a confirmed
  username and servers enabled, and a non-root user account (the owner) linked
  to that student in **both** directions (the account's `student_id` and the
  student's `user_id`). Extra attributes are passed through to the class and
  student factories via `:class` / `:student` option lists. Returns `%{auth,
  owner, student, class}`, with the owner and student read back the way the use
  cases read them.
  """
  @spec register_group_member(DateTime.t(), Keyword.t()) :: %{
          auth: Authentication.t(),
          owner: UserAccount.t(),
          student: Student.t(),
          class: ArchiDep.Course.Schemas.Class.t()
        }
  def register_group_member(now, opts \\ []) do
    class =
      case opts[:class] do
        %ArchiDep.Course.Schemas.Class{} = existing ->
          existing

        class_attrs ->
          CourseFactory.insert(
            :class,
            Keyword.merge([active: true, servers_enabled: true, now: now], class_attrs || [])
          )
      end

    student =
      CourseFactory.insert(
        :student,
        Keyword.merge(
          [
            class: class,
            active: true,
            servers_enabled: true,
            username_confirmed: true,
            user: nil,
            user_id: nil,
            now: now
          ],
          opts[:student] || []
        )
      )

    owner =
      AccountsFactory.insert(:user_account,
        username: :generate,
        root: false,
        active: true,
        switch_edu_id: nil,
        preregistered_user_id: student.id,
        now: now
      )

    {1, nil} =
      Repo.update_all(
        from(s in Student, where: s.id == ^student.id),
        set: [user_id: owner.id]
      )

    auth = Factory.build(:authentication, principal_id: owner.id, root: false)

    %{auth: auth, owner: owner, student: student, class: class}
  end

  @doc """
  Persists a server in the given group, owned by the given account, and returns
  it fully loaded the way the use cases read it (`Server.fetch_server/1`). Its
  expected-properties row shares the server ID, as a real server's does; pass
  `:properties` to set that row's values and any other key to override the
  server factory. The matching ID and the loaded read-back are why this is
  shared rather than inlined.
  """
  @spec insert_server(UUID.t(), UUID.t(), Keyword.t()) :: Server.t()
  def insert_server(owner_id, group_id, attrs \\ []) do
    id = UUID.generate()
    {properties, attrs} = Keyword.pop(attrs, :properties, [])

    expected_properties =
      ServersFactory.insert(:server_properties, Keyword.put(properties, :id, id))

    inserted =
      ServersFactory.insert(
        :server,
        Keyword.merge(
          [
            id: id,
            group_id: group_id,
            owner_id: owner_id,
            expected_properties: expected_properties,
            last_known_properties: nil
          ],
          attrs
        )
      )

    {:ok, server} = Server.fetch_server(inserted.id)
    server
  end

  @doc """
  Asserts the persisted `servers` row is byte-for-byte the given loaded server
  with its associations dropped — i.e. a rejected or no-op call left it
  untouched. Returns the server so it can be chained.
  """
  @spec assert_server_unchanged(Server.t()) :: Server.t()
  def assert_server_unchanged(%Server{} = server) do
    assert Repo.get!(Server, server.id) == %{
             server
             | group: not_loaded(:group, Server),
               owner: not_loaded(:owner, Server),
               expected_properties: not_loaded(:expected_properties, Server),
               last_known_properties: not_loaded(:last_known_properties, Server)
           }

    server
  end
end
