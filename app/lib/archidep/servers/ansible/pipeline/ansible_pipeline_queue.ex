defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue do
  @moduledoc """
  Ansible pipeline queue that tracks pending tasks such as gathering server
  facts or running playbooks, and manages their execution based on the demand
  from consumers. If a server goes offline, its pending tasks are dropped.
  """

  use GenStage

  import ArchiDep.Helpers.GenStageHelpers
  import ArchiDep.Helpers.PipeHelpers, only: [pair: 2]
  import ArchiDep.Helpers.ProcessHelpers
  import ArchiDep.Helpers.UseCaseHelpers
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias Ecto.Multi
  alias Ecto.UUID
  alias Phoenix.Tracker
  require Logger

  @tracker ArchiDep.Tracker

  defmodule State do
    @moduledoc false

    @enforce_keys [:pipeline, :pending_tasks]
    defstruct [
      :pipeline,
      :pending_tasks,
      stored_demand: 0,
      last_activity: nil
    ]

    @type gather_facts_task :: %{
            type: :gather_facts,
            server_id: UUID.t(),
            username: String.t(),
            cause: EventReference.t()
          }
    @type run_playbook_task :: %{
            type: :run_playbook,
            run_id: UUID.t(),
            server_id: UUID.t(),
            cause: EventReference.t()
          }
    # TODO: store unique connection ref and drop playbook run if it has changed
    @type pending_task :: gather_facts_task | run_playbook_task
    @type t :: %__MODULE__{
            stored_demand: non_neg_integer(),
            pending_tasks: {non_neg_integer(), :queue.queue(pending_task())},
            last_activity: DateTime.t() | nil
          }

    @type health_data :: %{
            pending: non_neg_integer(),
            demand: non_neg_integer(),
            last_activity: DateTime.t() | nil
          }

    @spec init(Pipeline.t()) :: t()
    def init(pipeline),
      do: %__MODULE__{
        pipeline: pipeline,
        stored_demand: 0,
        pending_tasks: {0, :queue.new()},
        last_activity: nil
      }

    @spec store_demand(t(), pos_integer) :: t
    def store_demand(state, demand) when is_demand(demand) do
      total_demand = state.stored_demand + demand

      Logger.debug(
        "Ansible pipeline queue received #{demand} new demand, total demand is #{total_demand}"
      )

      %__MODULE__{state | stored_demand: total_demand}
    end

    @spec gather_facts(
            t(),
            UUID.t(),
            String.t()
          ) :: t()
    def gather_facts(
          state,
          server_id,
          username
        ) do
      {number_pending, pending_tasks_queue} = state.pending_tasks

      new_last_activity =
        if number_pending == 0 do
          DateTime.utc_now()
        else
          state.last_activity
        end

      %__MODULE__{
        state
        | pending_tasks:
            {number_pending + 1,
             :queue.in(
               %{
                 type: :gather_facts,
                 server_id: server_id,
                 username: username
               },
               pending_tasks_queue
             )},
          last_activity: new_last_activity
      }
    end

    @spec run_playbook(
            t(),
            UUID.t(),
            UUID.t(),
            EventReference.t()
          ) :: t()
    def run_playbook(
          state,
          playbook_run_id,
          server_id,
          cause
        ) do
      {number_pending, pending_tasks_queue} = state.pending_tasks

      new_last_activity =
        if number_pending == 0 do
          DateTime.utc_now()
        else
          state.last_activity
        end

      %__MODULE__{
        state
        | pending_tasks:
            {number_pending + 1,
             :queue.in(
               %{
                 type: :run_playbook,
                 run_id: playbook_run_id,
                 server_id: server_id,
                 cause: cause
               },
               pending_tasks_queue
             )},
          last_activity: new_last_activity
      }
    end

    @spec server_offline(t(), UUID.t()) :: t()

    def server_offline(
          %__MODULE__{pending_tasks: {0, _pending_tasks_queue}} = state,
          _server_id
        ) do
      state
    end

    def server_offline(
          %__MODULE__{
            pending_tasks: {number_pending, pending_tasks_queue},
            last_activity: last_activity
          } = state,
          server_id
        ) do
      new_queue =
        :queue.filter(
          fn %{server_id: pending_server_id} -> pending_server_id != server_id end,
          pending_tasks_queue
        )

      new_number_pending = :queue.len(new_queue)

      Logger.debug(
        "Dropped #{number_pending - new_number_pending} task(s) for server #{server_id} which is now offline"
      )

      new_last_activity =
        if new_number_pending == 0 do
          nil
        else
          last_activity
        end

      %__MODULE__{
        state
        | pending_tasks: {new_number_pending, new_queue},
          last_activity: new_last_activity
      }
    end

    @spec consume_events(t()) :: {list({UUID.t(), EventReference.t()}), t()}
    def consume_events(state) do
      {events, new_state} = collect_events_to_consume({[], state})
      {Enum.reverse(events), new_state}
    end

    defp collect_events_to_consume(
           {events,
            %__MODULE__{
              pending_tasks: {0, _pending_tasks_queue}
            } = state}
         ) do
      {events, %__MODULE__{state | last_activity: nil}}
    end

    defp collect_events_to_consume(
           {events, %__MODULE__{pending_tasks: {number_pending, pending_tasks_queue}} = state}
         ) do
      {{:value, task}, new_queue} = :queue.out(pending_tasks_queue)

      event =
        case task do
          %{type: :gather_facts, server_id: server_id, username: username} ->
            {:gather_facts, server_id, username}

          %{type: :run_playbook, run_id: run_id, cause: cause} ->
            {:run_playbook, run_id, cause}
        end

      {[event | events],
       %__MODULE__{
         state
         | pending_tasks: {number_pending - 1, new_queue},
           last_activity: DateTime.utc_now()
       }}
    end

    @spec health(t()) :: health_data()
    def health(%__MODULE__{
          stored_demand: stored_demand,
          pending_tasks: {number_pending, _pending_tasks_queue},
          last_activity: last_activity
        }),
        do: %{
          pending: number_pending,
          demand: stored_demand,
          last_activity: last_activity
        }
  end

  @spec name(Pipeline.t()) :: GenServer.name()
  def name(pipeline), do: {:global, {__MODULE__, pipeline}}

  @spec start_link(Pipeline.t()) :: GenServer.on_start()
  def start_link(pipeline), do: GenStage.start_link(__MODULE__, pipeline, name: name(pipeline))

  @spec gather_facts(
          Pipeline.t(),
          Server.t(),
          String.t()
        ) :: :ok
  def gather_facts(
        pipeline,
        %Server{id: server_id},
        username
      ),
      do:
        GenStage.call(
          name(pipeline),
          {:gather_facts, server_id, username}
        )

  @spec run_playbook(
          Pipeline.t(),
          AnsiblePlaybookRun.t(),
          EventReference.t()
        ) :: :ok
  def run_playbook(pipeline, %AnsiblePlaybookRun{state: :pending} = playbook_run, cause),
    do:
      GenStage.call(
        name(pipeline),
        {:run_playbook, playbook_run.id, playbook_run.server_id, cause}
      )

  @spec server_offline(Pipeline.t(), Server.t()) :: :ok
  def server_offline(pipeline, %Server{id: server_id}),
    do: GenStage.cast(name(pipeline), {:server_offline, server_id})

  @spec health(Pipeline.t()) :: State.health_data()
  def health(pipeline), do: GenStage.call(name(pipeline), :health)

  @impl GenStage
  def init(pipeline) do
    set_process_label(__MODULE__)
    Logger.info("Init Ansible pipeline queue")

    mark_incomplete_playbook_runs_as_timed_out()

    pipeline
    |> State.init()
    |> track!()
    |> pair(:producer)
  end

  @impl GenStage
  def handle_demand(demand, state) when is_demand(demand),
    do:
      state
      |> State.store_demand(demand)
      |> State.consume_events()
      |> update_tracking!()
      |> noreply()

  @impl GenStage
  def handle_call(
        {:gather_facts, server_id, username},
        _from,
        state
      ),
      do:
        state
        |> State.gather_facts(server_id, username)
        |> State.consume_events()
        |> update_tracking!()
        |> reply(:ok)

  @impl GenStage
  def handle_call({:run_playbook, playbook_run_id, server_id, cause}, _from, state),
    do:
      state
      |> State.run_playbook(playbook_run_id, server_id, cause)
      |> State.consume_events()
      |> update_tracking!()
      |> reply(:ok)

  @impl GenStage
  def handle_call(:health, _from, state), do: {:reply, State.health(state), [], state}

  @impl GenStage
  def handle_cast({:server_offline, server_id}, state),
    do:
      state
      |> State.server_offline(server_id)
      |> State.consume_events()
      |> update_tracking!()
      |> noreply()

  defp mark_incomplete_playbook_runs_as_timed_out do
    incomplete_runs = AnsiblePlaybookRun.fetch_incomplete_runs()

    if Enum.any?(incomplete_runs) do
      Task.await_many(
        Enum.map(
          incomplete_runs,
          &Task.async(fn -> mark_incomplete_playbook_run_as_timed_out(&1) end)
        )
      )

      incomplete_runs_nb = length(incomplete_runs)
      Logger.notice("Marked #{incomplete_runs_nb} incomplete playbook runs as timed out")
    end
  end

  defp mark_incomplete_playbook_run_as_timed_out(run),
    do:
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.time_out(run))
      |> Multi.insert(:stored_event, &ansible_playbook_run_finished(&1.run))
      |> Repo.transaction()

  defp ansible_playbook_run_finished(run),
    do:
      run
      |> AnsiblePlaybookRunFinished.new()
      |> new_event(%{}, occurred_at: run.finished_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)

  defp track!(state) do
    {:ok, _ref} =
      Tracker.track(
        @tracker,
        self(),
        "ansible-queue",
        "queue:#{state.pipeline}",
        tracking_metadata(state)
      )

    state
  end

  defp update_tracking!({_events, state} = data) do
    {:ok, _ref} =
      Tracker.update(
        @tracker,
        self(),
        "ansible-queue",
        "queue:#{state.pipeline}",
        tracking_metadata(state)
      )

    data
  end

  defp tracking_metadata(%State{stored_demand: demand, pending_tasks: {tasks, _queue}}),
    do: %{
      demand: demand,
      pending: tasks
    }
end
