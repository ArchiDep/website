defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue do
  use GenStage

  require Logger
  import ArchiDep.Helpers.GenStageHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Ecto.UUID

  defmodule State do
    defstruct [:stored_demand, :pending_playbooks]

    @type t :: %__MODULE__{
            stored_demand: non_neg_integer(),
            pending_playbooks: {non_neg_integer(), :queue.queue(UUID.t())}
          }

    @spec init() :: t()
    def init(), do: %__MODULE__{stored_demand: 0, pending_playbooks: {0, :queue.new()}}

    @spec store_demand(t, pos_integer) :: t
    def store_demand(state, demand) when is_demand(demand) do
      total_demand = state.stored_demand + demand

      Logger.debug(
        "Ansible pipeline queue received #{demand} new demand, total demand is #{total_demand}"
      )

      %__MODULE__{state | stored_demand: total_demand}
    end

    @spec run_playbook(
            t(),
            UUID.t()
          ) :: t()
    def run_playbook(
          state,
          playbook_run_id
        ) do
      {number_pending, pending_playbooks_queue} = state.pending_playbooks

      %__MODULE__{
        state
        | pending_playbooks:
            {number_pending + 1, :queue.in(playbook_run_id, pending_playbooks_queue)}
      }
    end

    @spec consume_events(t()) :: {list(UUID.t()), t()}
    def consume_events(state) do
      {events, new_state} = collect_events_to_consume({[], state})
      {Enum.reverse(events), new_state}
    end

    defp collect_events_to_consume(
           {events, %__MODULE__{pending_playbooks: {0, _pending_playbooks_queue}} = state}
         ) do
      {events, state}
    end

    defp collect_events_to_consume(
           {events,
            %__MODULE__{pending_playbooks: {number_pending, pending_playbooks_queue}} = state}
         ) do
      {{:value, event}, new_queue} = :queue.out(pending_playbooks_queue)
      {[event | events], %__MODULE__{state | pending_playbooks: {number_pending - 1, new_queue}}}
    end
  end

  @spec name(Pipeline.t()) :: GenServer.name()
  def name(pipeline), do: {:global, {__MODULE__, pipeline}}

  @spec start_link(Pipeline.t()) :: GenServer.on_start()
  def start_link(pipeline), do: GenStage.start_link(__MODULE__, nil, name: name(pipeline))

  @spec run_playbook(
          Pipeline.t(),
          AnsiblePlaybookRun.t()
        ) :: :ok
  def run_playbook(pipeline, %AnsiblePlaybookRun{state: :pending} = playbook_run),
    do: GenStage.call(name(pipeline), {:run_playbook, playbook_run.id})

  @impl true
  def init(nil) do
    Logger.info("Init Ansible pipeline queue")
    {:producer, State.init()}
  end

  @impl true
  def handle_demand(demand, state) when is_demand(demand),
    do:
      state
      |> State.store_demand(demand)
      |> State.consume_events()
      |> noreply()

  @impl true
  def handle_call({:run_playbook, playbook_run_id}, _from, state),
    do:
      state
      |> State.run_playbook(playbook_run_id)
      |> State.consume_events()
      |> reply(:ok)
end
