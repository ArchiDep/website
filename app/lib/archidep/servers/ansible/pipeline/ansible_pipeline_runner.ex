defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner do
  @moduledoc """
  Runner that executes Ansible tasks from the queue, such as gathering server
  facts or running playbooks. An Elixir `Task` is started for each task.

  Ansible playbooks are only executed if the server is online. Playbook events
  are saved as they come in.
  """

  import ArchiDep.Helpers.UseCaseHelpers
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunRunning
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias Ecto.Multi
  alias Ecto.UUID
  alias Phoenix.Tracker
  require Logger

  @tracker ArchiDep.Tracker
  @event_base [:archidep, :servers, :ansible]

  @spec start_link(
          {:gather_facts, UUID.t(), String.t()}
          | {:run_playbook, UUID.t(), EventReference.t()}
        ) :: {:ok, pid()}
  def start_link(event),
    do:
      Task.start_link(fn ->
        process_event(event)
      end)

  @spec process_event({:gather_facts, UUID.t(), String.t()}) :: :ok
  def process_event({:gather_facts, server_id, username}) do
    {:ok, server} = Server.fetch_server(server_id)

    if ServerManager.online?(server) do
      Logger.debug("Gathering facts for server #{server.id}...")

      :telemetry.span(
        @event_base ++ [:gather_facts],
        %{server_id: server_id},
        fn ->
          {gather_server_facts(server, username), %{server_id: server_id}}
        end
      )
    else
      Logger.warning("Cannot gather facts for server #{server.id} because it is offline")
    end
  end

  @spec process_event({:run_playbook, UUID.t(), EventReference.t()}) :: :ok
  def process_event({:run_playbook, run_id, cause}) do
    case AnsiblePlaybookRun.get_pending_run(run_id) do
      nil ->
        Logger.warning("No pending Ansible playbook run found with ID #{run_id}")

      pending_run ->
        process_pending_run(pending_run, cause)
    end

    :ok
  end

  defp gather_server_facts(server, username) do
    case Ansible.gather_facts(server, username) do
      {:ok, facts} ->
        Logger.debug("Gathered facts for server #{server.id}")

        ServerManager.ansible_facts_gathered(server, {:ok, facts})

      {:error, reason} ->
        Logger.notice(
          "Failed to gather facts for server #{server.id} because: #{inspect(reason)}"
        )

        ServerManager.ansible_facts_gathered(server, {:error, reason})
    end
  end

  defp process_pending_run(pending_run, cause) do
    if ServerManager.online?(pending_run.server) do
      :telemetry.span(
        @event_base ++ [:playbook_run],
        start_event_metadata(pending_run),
        fn ->
          finished_run =
            pending_run |> run_playbook(cause) |> finished_run_from_result()

          {finished_run, finished_event_metadata(finished_run)}
        end
      )
    else
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.interrupt(pending_run))
      |> Multi.insert(:stored_event, &ansible_playbook_run_finished(&1.run, cause))
      |> Repo.transaction()
      |> then(fn {:ok, %{run: interrupted_run}} ->
        :telemetry.execute(
          @event_base ++ [:playbook_run, :interrupted],
          %{duration: AnsiblePlaybookRun.duration(interrupted_run)},
          finished_event_metadata(interrupted_run)
        )
      end)
    end
  end

  defp run_playbook(%AnsiblePlaybookRun{id: run_id} = pending_run, cause) do
    track_playbook!(run_id, %{type: :playbook, state: :pending, events: 0, current_task: nil})

    {:ok, %{run: running_run, stored_event: running_event}} =
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.start_running(pending_run))
      |> Multi.insert(:stored_event, &ansible_playbook_run_running(&1.run, cause))
      |> Repo.transaction()

    update_playbook_tracking!(run_id, fn meta -> %{meta | state: :running} end)

    running_run
    |> Ansible.run_playbook(cause, StoredEvent.to_reference(running_event))
    |> Stream.each(fn
      {:event, event} ->
        update_playbook_tracking!(run_id, fn meta ->
          %{meta | events: meta.events + 1, current_task: event.task_name}
        end)

        :ok = ServerManager.ansible_playbook_event(running_run, event)

      {:succeeded, succeeded_run} ->
        update_playbook_tracking!(run_id, fn meta ->
          %{meta | state: :succeeded, current_task: nil}
        end)

        :ok = ServerManager.ansible_playbook_completed(succeeded_run)

      {:failed, failed_run} ->
        update_playbook_tracking!(run_id, fn meta ->
          %{meta | state: :failed, current_task: nil}
        end)

        :ok = ServerManager.ansible_playbook_completed(failed_run)
    end)
    |> Enum.at(-1)
  end

  defp track_playbook!(run_id, meta) do
    {:ok, _ref} =
      Tracker.track(@tracker, self(), "ansible-queue", "playbook:#{run_id}", meta)
  end

  defp update_playbook_tracking!(run_id, update) do
    {:ok, _ref} =
      Tracker.update(@tracker, self(), "ansible-queue", "playbook:#{run_id}", update)
  end

  defp finished_run_from_result({:succeeded, run}), do: run
  defp finished_run_from_result({:failed, run}), do: run

  defp start_event_metadata(run),
    do: %{
      server_id: run.server_id,
      playbook: run.playbook
    }

  defp finished_event_metadata(run),
    do: %{
      state: run.state,
      server_id: run.server_id,
      playbook: run.playbook
    }

  defp ansible_playbook_run_running(run, cause),
    do:
      run
      |> AnsiblePlaybookRunRunning.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.started_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)

  defp ansible_playbook_run_finished(run, cause),
    do:
      run
      |> AnsiblePlaybookRunFinished.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.finished_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)
end
