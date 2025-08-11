defmodule ArchiDepWeb.Health.HealthController do
  @moduledoc false

  use ArchiDepWeb, :controller

  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias Plug.Conn

  @slow 1_000_000

  @spec health(Conn.t(), map) :: Conn.t()
  def health(conn, _params) do
    {health_time, health_data} = :timer.tc(&check_health/0)

    health_status =
      health_data
      |> Map.values()
      |> Enum.map(& &1.st)
      |> Enum.reduce(:ok, &worst_status/2)

    json(conn, %{
      st: slow_status(health_status, health_time),
      us: health_time,
      dt: health_data
    })
  end

  defp check_health do
    [{db_time, db_status}, {aq_time, {:ok, aq_status, aq_data}}] =
      Task.await_many([
        Task.async(fn -> :timer.tc(&check_db_health/0) end),
        Task.async(fn -> :timer.tc(&check_ansible_queue_health/0) end)
      ])

    %{
      db: %{
        st: slow_status(db_status, db_time),
        us: db_time
      },
      aq: %{
        st: slow_status(aq_status, aq_time),
        us: aq_time,
        dt: aq_data
      }
    }
  end

  defp check_ansible_queue_health do
    health = AnsiblePipelineQueue.health(Pipeline)

    aq_status =
      case health do
        %{pending: 0} ->
          :ok

        %{last_activity: nil} ->
          :error

        %{last_activity: last_activity} ->
          if DateTime.diff(DateTime.utc_now(), last_activity, :second) < 300 do
            :ok
          else
            :degraded
          end
      end

    {:ok, aq_status, health}
  end

  defp check_db_health do
    case Repo.query("SELECT 1 + 2") do
      {:ok, %{rows: [[3]]}} -> :ok
      _anything_else -> :error
    end
  end

  defp slow_status(:ok, time) when time >= @slow, do: :degraded
  defp slow_status(status, _time), do: status

  defp worst_status(:error, _anything_else), do: :error
  defp worst_status(_anything_else, :error), do: :error
  defp worst_status(:degraded, :ok), do: :degraded
  defp worst_status(:ok, :degraded), do: :degraded
  defp worst_status(:ok, :ok), do: :ok
end
