defmodule ArchiDep.Servers.ServerTracking.ServerDynamicSupervisorTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor

  test "starts per-server supervisors one for one" do
    assert ServerDynamicSupervisor.init(nil) ==
             {:ok,
              %{
                strategy: :one_for_one,
                intensity: 3,
                period: 5,
                max_children: :infinity,
                extra_arguments: []
              }}
  end
end
