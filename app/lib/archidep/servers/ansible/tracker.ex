defmodule ArchiDep.Servers.Ansible.Tracker do
  @moduledoc """
  Tracks the execution of Ansible playbooks, handling events during playbook
  runs, and saving them to the database.
  """

  import ArchiDep.Helpers.UseCaseHelpers
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Events.AnsiblePlaybookEventOccurred
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunStarted
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Multi
  require Logger

  @type ansible_playbook_run_event :: {:event, AnsiblePlaybookEvent.t()}
  @type ansible_playbook_run_succeeded :: {:succeeded, AnsiblePlaybookRun.t()}
  @type ansible_playbook_run_failed :: {:failed, AnsiblePlaybookRun.t()}
  @type ansible_playbook_run_element ::
          ansible_playbook_run_event()
          | ansible_playbook_run_succeeded()
          | ansible_playbook_run_failed()

  @spec track_playbook!(
          AnsiblePlaybook.t(),
          Server.t(),
          String.t(),
          Types.ansible_variables(),
          EventReference.t()
        ) ::
          {AnsiblePlaybookRun.t(), EventReference.t()}
  def track_playbook!(playbook, server, user, vars, causation_event) do
    case Multi.new()
         |> Multi.insert(:run, AnsiblePlaybookRun.new_pending(playbook, server, user, vars))
         |> Multi.insert(:stored_event, &ansible_playbook_run_started(&1.run, causation_event))
         |> Repo.transaction() do
      {:ok, %{run: run, stored_event: event}} -> {run, StoredEvent.to_reference(event)}
    end
  end

  @spec track_playbook_event(
          Runner.ansible_playbook_run_element(),
          AnsiblePlaybookRun.t(),
          EventReference.t(),
          EventReference.t()
        ) ::
          ansible_playbook_run_element()
  def track_playbook_event(element, run, started_cause, running_cause) do
    case element do
      {:event, data} ->
        {:ok, %{event: event}} =
          Multi.new()
          |> Multi.insert(:event, fn _changes -> AnsiblePlaybookEvent.new(data, run) end)
          |> Multi.update_all(
            :run_touch,
            fn %{event: event} ->
              AnsiblePlaybookRun.touch_new_event(run, event)
            end,
            []
          )
          |> Multi.merge(&update_playbook_stats(&1.event))
          |> Multi.insert(
            :stored_event,
            &ansible_playbook_event_occurred(&1.event, running_cause)
          )
          |> Repo.transaction()

        {:event, event}

      {:exit, reason} ->
        Logger.info("Ansible playbook run #{run.id} exited with reason: #{inspect(reason)}")

        case reason do
          {:status, 0} ->
            {:ok, %{run: succeeded_run}} =
              Multi.new()
              |> Multi.update(:run, AnsiblePlaybookRun.succeed(run))
              |> Multi.insert(
                :stored_event,
                &ansible_playbook_run_finished(&1.run, started_cause)
              )
              |> Repo.transaction()

            {:succeeded, succeeded_run}

          {:status, exit_code} ->
            {:ok, %{run: failed_run}} =
              Multi.new()
              |> Multi.update(:run, AnsiblePlaybookRun.fail(run, exit_code))
              |> Multi.insert(
                :stored_event,
                &ansible_playbook_run_finished(&1.run, started_cause)
              )
              |> Repo.transaction()

            {:failed, failed_run}

          :epipe ->
            {:ok, %{run: failed_run}} =
              Multi.new()
              |> Multi.update(:run, AnsiblePlaybookRun.fail(run, nil))
              |> Multi.insert(
                :stored_event,
                &ansible_playbook_run_finished(&1.run, started_cause)
              )
              |> Repo.transaction()

            {:failed, failed_run}
        end
    end
  end

  defp update_playbook_stats(%AnsiblePlaybookEvent{name: "v2_playbook_on_stats"} = event),
    do:
      Multi.update_all(
        Multi.new(),
        :update_stats,
        fn _changes ->
          AnsiblePlaybookRun.update_stats(event.run, event)
        end,
        []
      )

  defp update_playbook_stats(%AnsiblePlaybookEvent{}), do: Multi.new()

  defp ansible_playbook_run_started(run, cause),
    do:
      run
      |> AnsiblePlaybookRunStarted.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.created_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)

  defp ansible_playbook_event_occurred(event, cause),
    do:
      event
      |> AnsiblePlaybookEventOccurred.new()
      |> new_event(%{}, caused_by: cause, occurred_at: event.created_at)
      |> add_to_stream(event.run.server)
      |> initiated_by(event.run.server)

  defp ansible_playbook_run_finished(run, cause),
    do:
      run
      |> AnsiblePlaybookRunFinished.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.finished_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)
end
