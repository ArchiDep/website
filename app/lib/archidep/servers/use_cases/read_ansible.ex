defmodule ArchiDep.Servers.UseCases.ReadAnsible do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.PubSub.Scope
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.TrackerClient

  @spec fetch_ansible_playbook_runs(Authentication.t()) :: list(AnsiblePlaybookRun.t())
  def fetch_ansible_playbook_runs(auth) do
    authorize!(auth, Policy, :servers, :fetch_ansible_playbook_runs, nil)
    AnsiblePlaybookRun.fetch_runs()
  end

  @spec fetch_ansible_playbook_run(Authentication.t(), UUID.t()) ::
          {:ok, AnsiblePlaybookRun.t()} | {:error, :ansible_playbook_run_not_found}
  def fetch_ansible_playbook_run(auth, run_id) do
    with :ok <- validate_uuid(run_id, :ansible_playbook_run_not_found),
         {:ok, run} <- AnsiblePlaybookRun.fetch_run(run_id),
         :ok <- authorize(auth, Policy, :servers, :fetch_ansible_playbook_run, nil) do
      {:ok, run}
    else
      {:error, :ansible_playbook_run_not_found} ->
        {:error, :ansible_playbook_run_not_found}

      {:error, {:access_denied, :servers, :fetch_ansible_playbook_run}} ->
        {:error, :ansible_playbook_run_not_found}
    end
  end

  @spec fetch_ansible_playbook_events_for_run(Authentication.t(), UUID.t()) ::
          {:ok, list(AnsiblePlaybookEvent.t())} | {:error, :ansible_playbook_run_not_found}
  def fetch_ansible_playbook_events_for_run(auth, run_id) do
    with :ok <- validate_uuid(run_id, :ansible_playbook_run_not_found),
         {:ok, run} <- AnsiblePlaybookRun.fetch_run(run_id),
         :ok <- authorize(auth, Policy, :servers, :fetch_ansible_playbook_events_for_run, run) do
      {:ok, AnsiblePlaybookEvent.fetch_events_for_run(run_id)}
    else
      {:error, :ansible_playbook_run_not_found} ->
        {:error, :ansible_playbook_run_not_found}

      {:error, {:access_denied, :servers, :fetch_ansible_playbook_events_for_run}} ->
        {:error, :ansible_playbook_run_not_found}
    end
  end

  @spec subscribe_ansible_playbook_runs() :: :ok
  defdelegate subscribe_ansible_playbook_runs(), to: PubSub

  @spec tracked_ansible_playbook_runs() :: %{optional(String.t()) => map()}
  def tracked_ansible_playbook_runs do
    "ansible-queue"
    |> Scope.global_topic()
    |> TrackerClient.list()
    |> Enum.reduce(%{}, fn
      {"playbook:" <> run_id, %{type: :playbook} = meta}, acc -> Map.put(acc, run_id, meta)
      {_key, _meta}, acc -> acc
    end)
  end

  @spec refresh_ansible_playbook_runs(
          Authentication.t(),
          list(AnsiblePlaybookRun.t()),
          %{optional(String.t()) => map()},
          term()
        ) ::
          {:ok, list(AnsiblePlaybookRun.t()), %{optional(String.t()) => map()}} | :ignore
  def refresh_ansible_playbook_runs(
        auth,
        playbook_runs,
        tracked_playbooks,
        {action, "playbook:" <> run_id, %{type: :playbook} = meta}
      )
      when action in [:join, :update] and is_list(playbook_runs) and is_map(tracked_playbooks) do
    new_tracked_playbooks =
      Map.update(tracked_playbooks, run_id, meta, fn %{state: old_state, events: old_events} =
                                                       old_meta ->
        if meta.events > old_events or
             playbook_run_state_order(meta.state) > playbook_run_state_order(old_state) do
          meta
        else
          old_meta
        end
      end)

    new_meta = Map.get(new_tracked_playbooks, run_id)

    new_playbook_runs =
      if Enum.any?(playbook_runs, &(&1.id === run_id)) do
        Enum.map(playbook_runs, fn
          %AnsiblePlaybookRun{id: ^run_id} = run ->
            %AnsiblePlaybookRun{run | state: new_meta.state, number_of_events: new_meta.events}

          other_run ->
            other_run
        end)
      else
        # A run tracked for the first time is not in the list yet, so fetch it.
        # This goes through the public context boundary rather than the local
        # read so the consuming LiveView sees it as an ordinary context read
        # (authorized, and mockable) like every other run fetch.
        case ArchiDep.Servers.fetch_ansible_playbook_run(auth, run_id) do
          {:ok, new_run} -> add_new_playbook_run(playbook_runs, new_run)
          {:error, :ansible_playbook_run_not_found} -> playbook_runs
        end
      end

    {:ok, new_playbook_runs, new_tracked_playbooks}
  end

  def refresh_ansible_playbook_runs(
        auth,
        playbook_runs,
        tracked_playbooks,
        {:leave, "playbook:" <> run_id, _meta}
      )
      when is_list(playbook_runs) and is_map(tracked_playbooks) do
    new_playbook_runs =
      Enum.map(playbook_runs, fn
        %AnsiblePlaybookRun{id: ^run_id} = run ->
          case ArchiDep.Servers.fetch_ansible_playbook_run(auth, run_id) do
            {:ok, refetched_run} -> refetched_run
            {:error, :ansible_playbook_run_not_found} -> run
          end

        other_run ->
          other_run
      end)

    {:ok, new_playbook_runs, Map.delete(tracked_playbooks, run_id)}
  end

  def refresh_ansible_playbook_runs(_auth, _playbook_runs, _tracked_playbooks, _message),
    do: :ignore

  defp playbook_run_state_order(:pending), do: 1
  defp playbook_run_state_order(:running), do: 2
  defp playbook_run_state_order(_final_state), do: 3

  defp add_new_playbook_run([], new_run), do: [new_run]

  defp add_new_playbook_run(
         [%AnsiblePlaybookRun{created_at: most_recent_run_created_at} | _other_runs] =
           current_runs,
         %AnsiblePlaybookRun{created_at: new_run_created_at} = new_run
       )
       when new_run_created_at > most_recent_run_created_at,
       do: [new_run | current_runs]

  defp add_new_playbook_run(playbook_runs, new_run),
    do:
      playbook_runs
      |> Enum.reduce({new_run, []}, fn
        %AnsiblePlaybookRun{created_at: created_at} = existing_run,
        {%AnsiblePlaybookRun{created_at: new_run_created_at} = run_to_add, acc}
        when new_run_created_at > created_at ->
          {nil, [existing_run | [run_to_add | acc]]}

        existing_run, {run_to_add, acc} ->
          {run_to_add, [existing_run | acc]}
      end)
      |> elem(1)
      |> Enum.reverse()
end
