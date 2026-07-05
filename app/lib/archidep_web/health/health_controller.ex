defmodule ArchiDepWeb.Health.HealthController do
  @moduledoc false

  use ArchiDepWeb, :controller

  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClient
  alias Plug.Conn

  @type status :: :ok | :degraded | :error

  @slow 1_000_000

  @spec health(Conn.t(), map) :: Conn.t()
  def health(conn, _params) do
    {health_time, health_data} = :timer.tc(&check_health/0)

    health_status =
      health_data
      |> Map.values()
      |> Enum.map(& &1.st)
      |> Enum.reduce(:ok, &worst_status/2)

    response_status =
      case health_status do
        :error -> :internal_server_error
        _anything_else -> :ok
      end

    conn
    |> put_status(response_status)
    |> json(%{
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
    health = AnsiblePipelineQueueClient.health(Pipeline)

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
    case Repo.query("SELECT 1 + 2", [], log: false) do
      {:ok, %{rows: [[3]]}} -> :ok
      _anything_else -> :error
    end
  end

  @doc """
  Downgrades an `:ok` status to `:degraded` when the measured time (in
  microseconds) reaches the slow threshold; every other status is returned
  unchanged.
  """
  @spec slow_status(status(), non_neg_integer()) :: status()
  def slow_status(:ok, time) when time >= @slow, do: :degraded
  def slow_status(status, _time), do: status

  @doc """
  Reduces two component statuses to the worse of the two: `:error` dominates,
  then `:degraded`, otherwise `:ok`.
  """
  @spec worst_status(status(), status()) :: status()
  def worst_status(:error, _anything_else), do: :error
  def worst_status(_anything_else, :error), do: :error
  def worst_status(:degraded, :degraded), do: :degraded
  def worst_status(:degraded, :ok), do: :degraded
  def worst_status(:ok, :degraded), do: :degraded
  def worst_status(:ok, :ok), do: :ok
end
