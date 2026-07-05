defmodule ArchiDep.Servers.Schemas.ServerOwnerTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Errors.ServerOwnerNotFoundError
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]

  describe "fetch_authenticated/1" do
    test "fetches the authenticated group-member owner with its group member preloaded" do
      %{auth: auth, owner: owner} = ServersTestHelpers.register_group_member(@now)

      assert ServerOwner.fetch_authenticated(auth) == server_owner_view(owner.id)
    end

    test "fetches an authenticated root owner, whose group member is nil" do
      {auth, user_account} = ServersTestHelpers.register_root(@now)

      assert ServerOwner.fetch_authenticated(auth) == server_owner_view(user_account.id)
    end

    test "raises when no user account matches the authenticated principal" do
      auth = Factory.build(:authentication, principal_id: UUID.generate(), root: true)

      assert_raise ServerOwnerNotFoundError, fn -> ServerOwner.fetch_authenticated(auth) end
    end
  end

  describe "fetch_server_owner/1" do
    test "fetches a server owner with its group member preloaded by id" do
      %{owner: owner} = ServersTestHelpers.register_group_member(@now)

      assert ServerOwner.fetch_server_owner(owner.id) == {:ok, server_owner_view(owner.id)}
    end

    test "returns an error when no user account has the given id" do
      assert ServerOwner.fetch_server_owner(UUID.generate()) ==
               {:error, :server_owner_not_found}
    end
  end

  # The owner read back exactly as `fetch_authenticated/1` and
  # `fetch_server_owner/1` return it: the `user_accounts` row with its group
  # member (and that member's group and expected server properties) preloaded.
  defp server_owner_view(id),
    do:
      ServerOwner
      |> Repo.get!(id)
      |> Repo.preload(group_member: [group: :expected_server_properties])
end
