defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookRun do
  use ArchiDep, :schema

  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          playbook: String.t(),
          digest: binary(),
          host: Postgrex.INET.t(),
          port: 1..65_535,
          user: String.t(),
          vars: Types.ansible_variables(),
          server: Server.t() | NotLoaded,
          server_id: UUID.t(),
          state: Types.ansible_playbook_run_state(),
          started_at: DateTime.t(),
          finished_at: DateTime.t() | nil,
          number_of_events: non_neg_integer(),
          last_event_at: DateTime.t() | nil,
          exit_code: non_neg_integer() | nil,
          stats_changed: non_neg_integer(),
          stats_failures: non_neg_integer(),
          stats_ignored: non_neg_integer(),
          stats_ok: non_neg_integer(),
          stats_rescued: non_neg_integer(),
          stats_skipped: non_neg_integer(),
          stats_unreachable: non_neg_integer()
        }

  schema "ansible_playbook_runs" do
    field(:playbook, :string)
    field(:digest, :binary)
    field(:host, EctoNetwork.INET)
    field(:port, :integer)
    field(:user, :string)
    field(:vars, :map)
    belongs_to(:server, Server, type: :binary_id)

    field(:state, Ecto.Enum,
      values: [:pending, :running, :succeeded, :failed, :interrupted, :timeout]
    )

    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:number_of_events, :integer, default: 0)
    field(:last_event_at, :utc_datetime_usec)
    field(:exit_code, :integer)
    field(:stats_changed, :integer, default: 0)
    field(:stats_failures, :integer, default: 0)
    field(:stats_ignored, :integer, default: 0)
    field(:stats_ok, :integer, default: 0)
    field(:stats_rescued, :integer, default: 0)
    field(:stats_skipped, :integer, default: 0)
    field(:stats_unreachable, :integer, default: 0)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec successful_playbook_run?(Server.t(), AnsiblePlaybook.t()) :: boolean()
  def successful_playbook_run?(server, playbook) do
    from(r in __MODULE__,
      where:
        r.server_id == ^server.id and r.playbook == ^AnsiblePlaybook.name(playbook) and
          r.state == :succeeded,
      order_by: [desc: r.created_at],
      limit: 1
    )
    |> Repo.exists?()
  end

  @spec new_pending(AnsiblePlaybook.t(), Server.t(), String.t(), Types.ansible_variables()) ::
          Changeset.t(t())
  def new_pending(playbook, server, user, vars) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> change(
      id: id,
      playbook: AnsiblePlaybook.name(playbook),
      digest: playbook.digest,
      host: server.ip_address,
      port: server.ssh_port || 22,
      user: user,
      vars: vars,
      server_id: server.id,
      state: :pending,
      started_at: now,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  def touch_new_event(run, event) do
    id = run.id
    created_at = event.created_at

    from(r in __MODULE__,
      where: r.id == ^id,
      update: [
        set: [
          number_of_events: fragment("number_of_events + 1"),
          last_event_at: ^created_at,
          updated_at: ^created_at
        ]
      ]
    )
  end

  @spec update_stats(t(), AnsiblePlaybookEvent.t()) :: Ecto.Query.t()
  def update_stats(run, event) do
    id = run.id

    stats = get_in(event.data, ["stats", "archidep"]) || %{}
    changed = Map.get(stats, "changed") || 0
    failures = Map.get(stats, "failures") || 0
    ignored = Map.get(stats, "ignored") || 0
    ok = Map.get(stats, "ok") || 0
    rescued = Map.get(stats, "rescued") || 0
    skipped = Map.get(stats, "skipped") || 0
    unreachable = Map.get(stats, "unreachable") || 0

    from(r in __MODULE__,
      where: r.id == ^id,
      update: [
        set: [
          stats_changed: ^changed,
          stats_failures: ^failures,
          stats_ignored: ^ignored,
          stats_ok: ^ok,
          stats_rescued: ^rescued,
          stats_skipped: ^skipped,
          stats_unreachable: ^unreachable
        ]
      ]
    )
  end

  @spec succeed(t()) :: Changeset.t(t())
  def succeed(run) do
    now = DateTime.utc_now()

    run
    |> change(
      state: :succeeded,
      exit_code: 0,
      finished_at: now,
      updated_at: now
    )
    |> validate()
  end

  @spec fail(t(), non_neg_integer() | nil) :: Changeset.t(t())
  def fail(run, exit_code) when is_nil(exit_code) or (is_integer(exit_code) and exit_code >= 0) do
    now = DateTime.utc_now()

    run
    |> change(
      state: :failed,
      exit_code: exit_code,
      finished_at: now,
      updated_at: now
    )
    |> validate()
  end

  defp validate(changeset) do
    changeset
    |> update_change(:playbook, &trim/1)
    |> update_change(:user, &trim/1)
    |> validate_required([:playbook, :digest, :vars, :server_id, :state, :started_at])
    |> validate_length(:playbook, max: 50)
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> validate_length(:user, max: 32)
    |> assoc_constraint(:server)
    |> validate_inclusion(:state, [
      :pending,
      :running,
      :succeeded,
      :failed,
      :interrupted,
      :timeout
    ])
    |> validate_started_at_and_finished_at()
    |> validate_number(:number_of_events, greater_than_or_equal_to: 0)
    |> validate_number(:exit_code, greater_than_or_equal_to: 0)
    |> validate_number(:stats_changed, greater_than_or_equal_to: 0)
    |> validate_number(:stats_failures, greater_than_or_equal_to: 0)
    |> validate_number(:stats_ignored, greater_than_or_equal_to: 0)
    |> validate_number(:stats_ok, greater_than_or_equal_to: 0)
    |> validate_number(:stats_rescued, greater_than_or_equal_to: 0)
    |> validate_number(:stats_skipped, greater_than_or_equal_to: 0)
    |> validate_number(:stats_unreachable, greater_than_or_equal_to: 0)
  end

  defp validate_started_at_and_finished_at(changeset) do
    if changed?(changeset, :started_at) or changed?(changeset, :finished_at) do
      validate_started_at_and_finished_at(
        changeset,
        get_field(changeset, :started_at),
        get_field(changeset, :finished_at)
      )
    else
      changeset
    end
  end

  defp validate_started_at_and_finished_at(changeset, nil, _finished_at) do
    changeset
  end

  defp validate_started_at_and_finished_at(changeset, _started_at, nil) do
    changeset
  end

  defp validate_started_at_and_finished_at(changeset, started_at, finished_at) do
    if Date.compare(started_at, finished_at) == :gt do
      add_error(changeset, :finished_at, "must be after the start date")
    else
      changeset
    end
  end
end
