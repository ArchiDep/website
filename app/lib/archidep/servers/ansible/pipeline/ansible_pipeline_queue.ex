defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue do
  use GenStage

  require Logger
  import ArchiDep.Helpers.GenStageHelpers, only: [is_demand: 1]
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  defmodule State do
    defstruct [:stored_demand, :pending_playbooks]

    @type pending_playbook_item :: {
            AnsiblePlaybook.t(),
            AnsiblePlaybookRun.t(),
            reference()
          }
    @type t :: %__MODULE__{
            stored_demand: non_neg_integer(),
            pending_playbooks: {non_neg_integer(), :queue.queue(pending_playbook_item())}
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
            AnsiblePlaybook.t(),
            AnsiblePlaybookRun.t(),
            reference()
          ) :: t()
    def run_playbook(
          state,
          playbook,
          playbook_run,
          ref
        ) do
      {number_of_pending_playbooks, pending_playbooks_queue} = state.pending_playbooks

      %__MODULE__{
        state
        | pending_playbooks:
            {number_of_pending_playbooks + 1,
             :queue.in({playbook, playbook_run, ref}, pending_playbooks_queue)}
      }
    end
  end

  @spec name(Pipeline.t()) :: GenServer.name()
  def name(pipeline), do: {:global, {__MODULE__, pipeline}}

  @spec start_link(Pipeline.t()) :: GenServer.on_start()
  def start_link(pipeline), do: GenStage.start_link(__MODULE__, nil, name: name(pipeline))

  @spec run_playbook(
          Pipeline.t(),
          AnsiblePlaybook.t(),
          AnsiblePlaybookRun.t(),
          reference()
        ) :: :ok
  def run_playbook(pipeline, playbook, playbook_run, ref),
    do: GenStage.call(name(pipeline), {:run_playbook, playbook, playbook_run, ref})

  @impl true
  def init(nil) do
    Logger.info("Init Ansible pipeline queue")
    {:producer, State.init()}
  end

  @impl true
  def handle_demand(demand, state) when is_demand(demand) do
    events = []
    new_state = State.store_demand(state, demand)

    {:noreply, events, new_state}
  end

  @impl true
  def handle_call({:run_playbook, playbook, playbook_run, ref}, _from, state) do
    Logger.debug("Ansible pipeline queue received run_playbook call: #{inspect(playbook)}")

    new_state = State.run_playbook(state, playbook, playbook_run, ref)

    {:reply, :ok, [], new_state}
  end
end
