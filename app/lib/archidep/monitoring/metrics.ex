defmodule ArchiDep.Monitoring.Metrics do
  @moduledoc """
  Application-specific Prometheus metrics.
  """

  use PromEx.Plugin

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server

  @one_minute 60_000
  @accounts_event [:archidep, :accounts, :data]
  @servers_event [:archidep, :servers, :data]

  @impl PromEx.Plugin
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, @one_minute)

    [
      accounts_metrics(poll_rate),
      servers_metrics(poll_rate)
    ]
  end

  defp accounts_metrics(poll_rate) do
    Polling.build(
      :archidep_accounts_polling_events,
      poll_rate,
      {__MODULE__, :execute_accounts_metrics, []},
      [
        last_value(
          [:archidep, :accounts, :data, :active_user_accounts_count],
          event_name: @accounts_event,
          description: "The number of registered user accounts that are currently active.",
          measurement: :active_user_accounts_count,
          unit: :count
        ),
        last_value(
          [:archidep, :accounts, :data, :user_accounts_count],
          event_name: @accounts_event,
          description: "The number of registered user accounts.",
          measurement: :user_accounts_count,
          unit: :count
        )
      ]
    )
  end

  defp servers_metrics(poll_rate) do
    Polling.build(
      :archidep_servers_polling_events,
      poll_rate,
      {__MODULE__, :execute_servers_metrics, []},
      [
        last_value(
          [:archidep, :servers, :data, :active_servers_count],
          event_name: @servers_event,
          description: "The number of registered servers that are currently active.",
          measurement: :active_servers_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :ansible_playbook_events_count],
          event_name: @servers_event,
          description: "The number of Ansible playbook events processed so far.",
          measurement: :ansible_playbook_events_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :ansible_playbook_runs_count],
          event_name: @servers_event,
          description: "The number of Ansible playbook runs executed so far.",
          measurement: :ansible_playbook_runs_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :servers_count],
          event_name: @servers_event,
          description: "The number of registered servers.",
          measurement: :servers_count,
          unit: :count
        )
      ]
    )
  end

  @spec execute_accounts_metrics() :: :ok
  def execute_accounts_metrics do
    running_repos = Ecto.Repo.all_running()

    if Enum.member?(running_repos, Repo) do
      :telemetry.execute(
        @accounts_event,
        compute_accounts_metrics(),
        %{}
      )
    end

    :ok
  end

  @spec execute_servers_metrics() :: :ok
  def execute_servers_metrics do
    running_repos = Ecto.Repo.all_running()

    if Enum.member?(running_repos, Repo) do
      :telemetry.execute(
        @servers_event,
        compute_servers_metrics(),
        %{}
      )
    end

    :ok
  end

  @spec seed_event_metrics() :: :ok
  def seed_event_metrics do
    :telemetry.execute(
      @accounts_event,
      %{
        active_user_accounts_count: -1,
        user_accounts_count: -1
      },
      %{}
    )

    :telemetry.execute(
      @servers_event,
      %{
        active_servers_count: -1,
        ansible_playbook_events_count: -1,
        ansible_playbook_runs_count: -1,
        servers_count: -1
      },
      %{}
    )
  end

  defp compute_accounts_metrics do
    now = DateTime.utc_now()
    active_user_accounts_count = UserAccount.count_active_users(now)
    user_accounts_count = Repo.aggregate(UserAccount, :count, :id)

    %{
      active_user_accounts_count: active_user_accounts_count,
      user_accounts_count: user_accounts_count
    }
  end

  defp compute_servers_metrics do
    now = DateTime.utc_now()
    active_servers_count = Server.count_active_servers(now)
    ansible_playbook_runs_count = Repo.aggregate(AnsiblePlaybookRun, :count, :id)
    ansible_playbook_events_count = Repo.aggregate(AnsiblePlaybookEvent, :count, :id)
    servers_count = Repo.aggregate(Server, :count, :id)

    %{
      active_servers_count: active_servers_count,
      ansible_playbook_events_count: ansible_playbook_events_count,
      ansible_playbook_runs_count: ansible_playbook_runs_count,
      servers_count: servers_count
    }
  end
end
