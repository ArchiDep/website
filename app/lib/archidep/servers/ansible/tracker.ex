defmodule ArchiDep.Servers.Ansible.Tracker do
  require Logger
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Multi

  @type ansible_playbook_run_started :: {:started, AnsiblePlaybookRun.t()}
  @type ansible_playbook_run_event :: {:event, AnsiblePlaybookEvent.t()}
  @type ansible_playbook_run_succeeded :: {:succeeded, AnsiblePlaybookRun.t()}
  @type ansible_playbook_run_failed :: {:failed, AnsiblePlaybookRun.t()}
  @type ansible_playbook_run_element ::
          ansible_playbook_run_started()
          | ansible_playbook_run_event()
          | ansible_playbook_run_succeeded()
          | ansible_playbook_run_failed()

  @spec track_playbook!(AnsiblePlaybook.t(), Server.t(), String.t(), Types.ansible_variables()) ::
          AnsiblePlaybookRun.t()
  def track_playbook!(playbook, server, user, vars) do
    run = playbook |> AnsiblePlaybookRun.new_pending(server, user, vars) |> Repo.insert!()
    %AnsiblePlaybookRun{run | server: server}
  end

  @spec track_playbook_event(Runner.ansible_playbook_run_element(), AnsiblePlaybookRun.t()) ::
          ansible_playbook_run_element()
  def track_playbook_event(element, run) do
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
          |> Multi.merge(fn %{event: event} ->
            if event.name == "v2_playbook_on_stats" do
              Multi.new()
              |> Multi.update_all(
                :run_stats,
                fn _changes ->
                  AnsiblePlaybookRun.update_stats(run, event)
                end,
                []
              )
            else
              Multi.new()
            end
          end)
          |> Repo.transaction()

        {:event, event}

      {:exit, reason} ->
        Logger.info("Ansible playbook run #{run.id} exited with reason: #{inspect(reason)}")

        case reason do
          {:status, 0} ->
            {:succeeded, run |> AnsiblePlaybookRun.succeed() |> Repo.update!()}

          {:status, exit_code} ->
            {:failed, run |> AnsiblePlaybookRun.fail(exit_code) |> Repo.update!()}

          :epipe ->
            {:failed, run |> AnsiblePlaybookRun.fail(nil) |> Repo.update!()}
        end
    end
  end
end
