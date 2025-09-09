defmodule ArchiDep.Monitoring.Metrics do
  @moduledoc """
  Application-specific Prometheus metrics.
  """

  use PromEx.Plugin

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias Phoenix.Tracker
  require Logger

  @accounts_data_event [:archidep, :accounts, :data]
  @auth_login_event [:archidep, :accounts, :auth, :login]
  @auth_logout_event [:archidep, :accounts, :auth, :logout]

  @course_data_event [:archidep, :course, :data]
  @events_data_event [:archidep, :events, :data]

  @servers_data_event [:archidep, :servers, :data]
  @server_ansible_playbook_run_stop_event [:archidep, :servers, :ansible, :playbook_run, :stop]
  @server_ansible_playbook_run_exception_event [
    :archidep,
    :servers,
    :ansible,
    :playbook_run,
    :exception
  ]
  @server_connected_event [:archidep, :servers, :tracking, :connected]
  @server_connection_crashed_event [:archidep, :servers, :tracking, :connected]
  @server_up_event [:archidep, :servers, :tracking, :up]

  @poll_rate :archidep
             |> Application.compile_env!(:monitoring)
             |> Keyword.fetch!(:metrics_poll_rate)

  @tracker ArchiDep.Tracker

  @impl PromEx.Plugin
  def event_metrics(_opts) do
    Event.build(
      :archidep_events,
      [
        counter([:archidep, :accounts, :auth, :login, :count],
          event_name: @auth_login_event,
          measurement: :count,
          description: "The number of successful user logins.",
          unit: :count
        ),
        counter([:archidep, :accounts, :auth, :logout, :count],
          event_name: @auth_logout_event,
          measurement: :count,
          description: "The number of successful user logouts.",
          unit: :count
        ),
        counter([:archidep, :servers, :ansible, :playbook_run, :stop, :count],
          event_name: @server_ansible_playbook_run_stop_event,
          measurement: :count,
          description: "The number of finished Ansible playbook runs.",
          unit: :count,
          tags: [:playbook, :server_id, :state]
        ),
        counter([:archidep, :servers, :ansible, :playbook_run, :exception, :count],
          event_name: @server_ansible_playbook_run_exception_event,
          measurement: :count,
          description:
            "The number of Ansible playbook runs that did not finish because of an exception.",
          unit: :count,
          tags: [:playbook, :server_id, :state]
        ),
        counter([:archidep, :servers, :tracking, :connected, :count],
          event_name: @server_connected_event,
          measurement: :count,
          description: "The number of successful server connections.",
          unit: :count
        ),
        distribution([:archidep, :servers, :tracking, :connected, :duration, :seconds],
          event_name: @server_connected_event,
          measurement: :duration,
          description: "The time taken to connect to a server.",
          unit: :second,
          reporter_options: [
            buckets: [0.1, 0.5, 1, 2, 5, 10, 30, 60]
          ]
        ),
        counter([:archidep, :servers, :tracking, :connection_crash, :count],
          event_name: @server_connection_crashed_event,
          measurement: :count,
          description: "The number of times a server connection crashed.",
          unit: :count
        ),
        distribution([:archidep, :servers, :tracking, :connection_crash, :duration, :seconds],
          event_name: @server_connection_crashed_event,
          measurement: :duration,
          description: "The time a server connection was alive before it crashed.",
          unit: :second,
          reporter_options: [
            buckets: [1, 60, 300, 1800, 3_600, 21_600, 43_200, 86_400, 172_800]
          ]
        ),
        counter([:archidep, :servers, :tracking, :up, :count],
          event_name: @server_up_event,
          measurement: :count,
          description: "The number of times a server notified the application that it was up.",
          unit: :count
        )
      ]
    )
  end

  @impl PromEx.Plugin
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, @poll_rate)

    [
      accounts_metrics(poll_rate),
      course_metrics(poll_rate),
      events_metrics(poll_rate),
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
          [:archidep, :accounts, :data, :user_accounts_active_count],
          event_name: @accounts_data_event,
          description: "The number of registered user accounts that are currently active.",
          measurement: :user_accounts_active_count,
          unit: :count
        ),
        last_value(
          [:archidep, :accounts, :data, :user_accounts_count],
          event_name: @accounts_data_event,
          description: "The number of registered user accounts.",
          measurement: :user_accounts_count,
          unit: :count
        ),
        last_value(
          [:archidep, :accounts, :data, :user_sessions_active_count],
          event_name: @accounts_data_event,
          description: "The number of active user sessions.",
          measurement: :user_sessions_active_count,
          unit: :count
        ),
        last_value(
          [:archidep, :accounts, :data, :user_sessions_count],
          event_name: @accounts_data_event,
          description: "The number of user sessions.",
          measurement: :user_sessions_count,
          unit: :count
        )
      ]
    )
  end

  defp course_metrics(poll_rate) do
    Polling.build(
      :archidep_course_polling_events,
      poll_rate,
      {__MODULE__, :execute_course_metrics, []},
      [
        last_value(
          [:archidep, :course, :data, :students_registered_count],
          event_name: @course_data_event,
          description:
            "The number of students that have logged in and registered their user account.",
          measurement: :students_registered_count,
          unit: :count
        )
      ]
    )
  end

  defp events_metrics(poll_rate) do
    Polling.build(
      :archidep_events_polling_events,
      poll_rate,
      {__MODULE__, :execute_events_metrics, []},
      [
        last_value(
          [:archidep, :events, :data, :events_count],
          event_name: @events_data_event,
          description: "The number of events stored in the system.",
          measurement: :events_count,
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
          [:archidep, :servers, :data, :ansible_pipeline_queue_demand_count],
          event_name: @servers_data_event,
          description: "The unfulfilled demand in the Ansible pipeline queue.",
          measurement: :ansible_pipeline_queue_demand_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :ansible_pipeline_queue_pending_count],
          event_name: @servers_data_event,
          description: "The number of pending playbook runs in the Ansible pipeline queue.",
          measurement: :ansible_pipeline_queue_pending_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :ansible_playbook_events_count],
          event_name: @servers_data_event,
          description: "The number of Ansible playbook events processed so far.",
          measurement: :ansible_playbook_events_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :ansible_playbook_runs_count],
          event_name: @servers_data_event,
          description: "The number of Ansible playbook runs executed so far.",
          measurement: :ansible_playbook_runs_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :servers_active_count],
          event_name: @servers_data_event,
          description: "The number of registered servers that are currently active.",
          measurement: :servers_active_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :servers_connected_count],
          event_name: @servers_data_event,
          description: "The number of servers that the application is currently connected to.",
          measurement: :servers_connected_count,
          unit: :count
        ),
        last_value(
          [:archidep, :servers, :data, :servers_count],
          event_name: @servers_data_event,
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
        @accounts_data_event,
        compute_accounts_metrics(),
        %{}
      )
    else
      Logger.info(
        "Skipping accounts metrics execution because the Repo is not running. Will poll again in #{inspect(@poll_rate)}ms."
      )
    end

    :ok
  end

  @spec execute_course_metrics() :: :ok
  def execute_course_metrics do
    running_repos = Ecto.Repo.all_running()

    if Enum.member?(running_repos, Repo) do
      :telemetry.execute(
        @course_data_event,
        compute_course_metrics(),
        %{}
      )
    else
      Logger.info(
        "Skipping course metrics execution because the Repo is not running. Will poll again in #{inspect(@poll_rate)}ms."
      )
    end

    :ok
  end

  @spec execute_events_metrics() :: :ok
  def execute_events_metrics do
    running_repos = Ecto.Repo.all_running()

    if Enum.member?(running_repos, Repo) do
      :telemetry.execute(
        @events_data_event,
        compute_events_metrics(),
        %{}
      )
    else
      Logger.info(
        "Skipping events metrics execution because the Repo is not running. Will poll again in #{inspect(@poll_rate)}ms."
      )
    end

    :ok
  end

  @spec execute_servers_metrics() :: :ok
  def execute_servers_metrics do
    running_repos = Ecto.Repo.all_running()

    if Enum.member?(running_repos, Repo) do
      :telemetry.execute(
        @servers_data_event,
        compute_servers_metrics(),
        %{}
      )
    else
      Logger.info(
        "Skipping servers metrics execution because the Repo is not running. Will poll again in #{inspect(@poll_rate)}ms."
      )
    end

    :ok
  end

  @spec seed_event_metrics() :: :ok
  def seed_event_metrics do
    :telemetry.execute(
      @accounts_data_event,
      %{
        user_accounts_active_count: -1,
        user_accounts_count: -1,
        user_sessions_active_count: -1,
        user_sessions_count: -1
      },
      %{}
    )

    :telemetry.execute(
      @course_data_event,
      %{
        students_registered_count: -1
      },
      %{}
    )

    :telemetry.execute(
      @events_data_event,
      %{
        events_count: -1
      },
      %{}
    )

    :telemetry.execute(
      @servers_data_event,
      %{
        ansible_pipeline_queue_demand_count: -1,
        ansible_pipeline_queue_pending_count: -1,
        ansible_playbook_events_count: -1,
        ansible_playbook_runs_count: -1,
        servers_active_count: -1,
        servers_connected_count: -1,
        servers_count: -1
      },
      %{}
    )
  end

  defp compute_accounts_metrics do
    now = DateTime.utc_now()
    user_accounts_active_count = UserAccount.count_active_users(now)
    user_accounts_count = Repo.aggregate(UserAccount, :count, :id)
    user_sessions_active_count = UserSession.count_active_sessions(now)
    user_sessions_count = Repo.aggregate(UserSession, :count, :id)

    %{
      user_accounts_active_count: user_accounts_active_count,
      user_accounts_count: user_accounts_count,
      user_sessions_active_count: user_sessions_active_count,
      user_sessions_count: user_sessions_count
    }
  end

  defp compute_course_metrics do
    students_registered_count = Student.count_registered_students()

    %{
      students_registered_count: students_registered_count
    }
  end

  defp compute_events_metrics do
    events_count = Repo.aggregate(StoredEvent, :count, :id)

    %{
      events_count: events_count
    }
  end

  defp compute_servers_metrics do
    now = DateTime.utc_now()

    ansible_pipeline_queue_health = AnsiblePipelineQueue.health(Pipeline)
    ansible_pipeline_queue_demand_count = Map.get(ansible_pipeline_queue_health, :demand, 0)
    ansible_pipeline_queue_pending_count = Map.get(ansible_pipeline_queue_health, :pending, 0)

    ansible_playbook_runs_count = Repo.aggregate(AnsiblePlaybookRun, :count, :id)
    ansible_playbook_events_count = Repo.aggregate(AnsiblePlaybookEvent, :count, :id)
    servers_active_count = Server.count_active_servers(now)

    servers_connected_count =
      @tracker
      |> Tracker.list("servers")
      |> Enum.reduce(0, fn {_key, %{state: state}}, acc ->
        if connected?(state.connection_state), do: acc + 1, else: acc
      end)

    servers_count = Repo.aggregate(Server, :count, :id)

    %{
      ansible_pipeline_queue_demand_count: ansible_pipeline_queue_demand_count,
      ansible_pipeline_queue_pending_count: ansible_pipeline_queue_pending_count,
      ansible_playbook_events_count: ansible_playbook_events_count,
      ansible_playbook_runs_count: ansible_playbook_runs_count,
      servers_active_count: servers_active_count,
      servers_connected_count: servers_connected_count,
      servers_count: servers_count
    }
  end
end
