defmodule ArchiDepWeb.EndpointTest do
  use ExUnit.Case, async: true

  alias ArchiDepWeb.Endpoint

  describe "log_level/1" do
    test "disables logging for the health check route" do
      assert Endpoint.log_level(%{path_info: ["api", "health"]}) == false
    end

    test "logs any other route at the info level" do
      assert Endpoint.log_level(%{path_info: ["app"]}) == :info
      assert Endpoint.log_level(%{path_info: []}) == :info
    end
  end
end
