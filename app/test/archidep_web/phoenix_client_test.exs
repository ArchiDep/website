defmodule ArchiDepWeb.PhoenixClientTest do
  use ExUnit.Case, async: true

  # npm installs the Phoenix JavaScript client once for the whole repository,
  # and both the course material and the dashboard bundle that copy, rather than
  # the one in `deps/` that comes with the Elixir dependency.
  @package_lock Path.expand("../../../package-lock.json", __DIR__)

  test "npm installs the JavaScript client of the Phoenix version the application runs" do
    lock = @package_lock |> File.read!() |> Jason.decode!()

    assert get_in(lock, ["packages", "node_modules/phoenix", "version"]) ==
             to_string(Application.spec(:phoenix, :vsn))
  end
end
