defmodule ArchiDepWeb.Health.HealthControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClientMock
  alias ArchiDepWeb.Health.HealthController

  setup :verify_on_exit!

  describe "GET /api/health" do
    test "reports an ok status when the database and the ansible queue are healthy", %{conn: conn} do
      expect(AnsiblePipelineQueueClientMock, :health, fn Pipeline ->
        %{pending: 0, demand: 0, last_activity: nil}
      end)

      conn = get(conn, ~p"/api/health")

      assert conn.status == 200

      assert health_projection(json_response(conn, 200)) == %{
               "st" => "ok",
               "us" => :measured,
               "dt" => %{
                 "db" => %{"st" => "ok", "us" => :measured},
                 "aq" => %{
                   "st" => "ok",
                   "us" => :measured,
                   "dt" => %{"pending" => 0, "demand" => 0, "last_activity" => nil}
                 }
               }
             }
    end

    test "reports a 500 error when the ansible queue has pending tasks but no activity", %{
      conn: conn
    } do
      expect(AnsiblePipelineQueueClientMock, :health, fn Pipeline ->
        %{pending: 3, demand: 1, last_activity: nil}
      end)

      conn = get(conn, ~p"/api/health")

      assert conn.status == 500

      assert health_projection(json_response(conn, 500)) == %{
               "st" => "error",
               "us" => :measured,
               "dt" => %{
                 "db" => %{"st" => "ok", "us" => :measured},
                 "aq" => %{
                   "st" => "error",
                   "us" => :measured,
                   "dt" => %{"pending" => 3, "demand" => 1, "last_activity" => nil}
                 }
               }
             }
    end

    test "reports an ok status when the ansible queue had recent activity", %{conn: conn} do
      last_activity = DateTime.utc_now()

      expect(AnsiblePipelineQueueClientMock, :health, fn Pipeline ->
        %{pending: 3, demand: 1, last_activity: last_activity}
      end)

      conn = get(conn, ~p"/api/health")

      assert conn.status == 200

      assert health_projection(json_response(conn, 200)) == %{
               "st" => "ok",
               "us" => :measured,
               "dt" => %{
                 "db" => %{"st" => "ok", "us" => :measured},
                 "aq" => %{
                   "st" => "ok",
                   "us" => :measured,
                   "dt" => %{
                     "pending" => 3,
                     "demand" => 1,
                     "last_activity" => DateTime.to_iso8601(last_activity)
                   }
                 }
               }
             }
    end

    test "reports a degraded status when the ansible queue activity is stale", %{conn: conn} do
      last_activity = DateTime.add(DateTime.utc_now(), -400, :second)

      expect(AnsiblePipelineQueueClientMock, :health, fn Pipeline ->
        %{pending: 3, demand: 1, last_activity: last_activity}
      end)

      conn = get(conn, ~p"/api/health")

      assert conn.status == 200

      assert health_projection(json_response(conn, 200)) == %{
               "st" => "degraded",
               "us" => :measured,
               "dt" => %{
                 "db" => %{"st" => "ok", "us" => :measured},
                 "aq" => %{
                   "st" => "degraded",
                   "us" => :measured,
                   "dt" => %{
                     "pending" => 3,
                     "demand" => 1,
                     "last_activity" => DateTime.to_iso8601(last_activity)
                   }
                 }
               }
             }
    end
  end

  describe "worst_status/2" do
    test "reduces two component statuses to the worse of the two" do
      for {left, right, expected} <- [
            {:ok, :ok, :ok},
            {:ok, :degraded, :degraded},
            {:ok, :error, :error},
            {:degraded, :ok, :degraded},
            {:degraded, :degraded, :degraded},
            {:degraded, :error, :error},
            {:error, :ok, :error},
            {:error, :degraded, :error},
            {:error, :error, :error}
          ] do
        assert HealthController.worst_status(left, right) == expected
      end
    end
  end

  describe "slow_status/2" do
    test "downgrades an ok status to degraded once the slow threshold is reached" do
      assert HealthController.slow_status(:ok, 1_000_000) == :degraded
      assert HealthController.slow_status(:ok, 2_000_000) == :degraded
    end

    test "leaves an ok status below the slow threshold unchanged" do
      assert HealthController.slow_status(:ok, 999_999) == :ok
      assert HealthController.slow_status(:ok, 0) == :ok
    end

    test "leaves a non-ok status unchanged regardless of the time" do
      assert HealthController.slow_status(:degraded, 5_000_000) == :degraded
      assert HealthController.slow_status(:error, 5_000_000) == :error
    end
  end

  # The `us` fields hold the measured microsecond timings, which vary per run;
  # assert each is a non-negative integer and normalize it out so the rest of
  # the response body can be pinned by whole-value equality.
  defp health_projection(body) do
    assert is_integer(body["us"]) and body["us"] >= 0
    assert is_integer(body["dt"]["db"]["us"]) and body["dt"]["db"]["us"] >= 0
    assert is_integer(body["dt"]["aq"]["us"]) and body["dt"]["aq"]["us"] >= 0

    body
    |> put_in(["us"], :measured)
    |> put_in(["dt", "db", "us"], :measured)
    |> put_in(["dt", "aq", "us"], :measured)
  end
end
