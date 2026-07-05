defmodule ArchiDep.Servers.Schemas.ServerGroupTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Support.CourseFactory
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]

  describe "fetch_server_group/1" do
    test "fetches a server group with its expected server properties by id" do
      class = CourseFactory.insert(:class, now: @now)

      expected =
        ServerGroup
        |> Repo.get!(class.id)
        |> Repo.preload(:expected_server_properties)

      assert ServerGroup.fetch_server_group(class.id) == {:ok, expected}
    end

    test "returns an error when no server group has the given id" do
      assert ServerGroup.fetch_server_group(UUID.generate()) ==
               {:error, :server_group_not_found}
    end
  end
end
