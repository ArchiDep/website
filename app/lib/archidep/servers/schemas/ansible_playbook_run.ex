defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookRun do
  @moduledoc """
  An Ansible playbook run on a server, which may consist of multiple events (see
  `ArchiDep.Servers.Schemas.AnsiblePlaybookEvent`). This schema represents the
  state of the playbook run, including its configuration, execution state, and
  statistics about the run.
  """

  use ArchiDep, :schema

  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Git
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Query

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          playbook: String.t(),
          playbook_path: String.t(),
          digest: binary(),
          git_revision: String.t(),
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
          stats_unreachable: non_neg_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "ansible_playbook_runs" do
    field(:playbook, :string)
    field(:playbook_path, :string)
    field(:digest, :binary)
    field(:git_revision, :string)
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

  @spec done?(t()) :: boolean()
  def done?(%__MODULE__{state: state}) when state in [:pending, :running],
    do: false

  def done?(%__MODULE__{}), do: true

  @spec stats(t()) :: Types.ansible_stats()
  def stats(%__MODULE__{
        stats_changed: changed,
        stats_failures: failures,
        stats_ignored: ignored,
        stats_ok: ok,
        stats_rescued: rescued,
        stats_skipped: skipped,
        stats_unreachable: unreachable
      }),
      do: %{
        changed: changed,
        failures: failures,
        ignored: ignored,
        ok: ok,
        rescued: rescued,
        skipped: skipped,
        unreachable: unreachable
      }

  @spec get_pending_run!(UUID.t()) :: t()
  def get_pending_run!(id),
    do:
      Repo.one!(
        from(r in __MODULE__,
          where: r.id == ^id and r.state == :pending,
          join: s in assoc(r, :server),
          preload: [server: s]
        )
      )

  @spec get_completed_run!(UUID.t()) :: t()
  def get_completed_run!(id),
    do:
      Repo.one!(
        from(r in __MODULE__,
          where: r.id == ^id and r.state != :pending and r.state != :running,
          join: s in assoc(r, :server),
          preload: [server: s]
        )
      )

  @spec get_last_playbook_run(Server.t(), AnsiblePlaybook.t()) :: t() | nil
  def get_last_playbook_run(server, playbook),
    do:
      Repo.one(
        from(r in __MODULE__,
          where: r.server_id == ^server.id and r.playbook == ^AnsiblePlaybook.name(playbook),
          order_by: [desc: r.created_at],
          limit: 1
        )
      )

  @spec fetch_runs() :: list(t())
  def fetch_runs do
    Repo.all(
      from(r in __MODULE__,
        join: s in assoc(r, :server),
        order_by: [desc: r.started_at],
        preload: [server: s]
      )
    )
  end

  @spec fetch_run(UUID.t()) :: {:ok, t()} | {:error, :ansible_playbook_run_not_found}
  def fetch_run(id),
    do:
      Repo.one(
        from(r in __MODULE__,
          where: r.id == ^id,
          join: s in assoc(r, :server),
          preload: [server: s]
        )
      )
      |> truthy_or(:ansible_playbook_run_not_found)

  @spec new_pending(AnsiblePlaybook.t(), Server.t(), String.t(), Types.ansible_variables()) ::
          Changeset.t(t())
  def new_pending(playbook, server, user, vars) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> change(
      id: id,
      playbook: AnsiblePlaybook.name(playbook),
      playbook_path: playbook.relative_path,
      digest: playbook.digest,
      git_revision: Git.git_revision(),
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

  @spec start_running(t()) :: Changeset.t(t())
  def start_running(%__MODULE__{state: :pending} = run) do
    now = DateTime.utc_now()

    run
    |> change(
      state: :running,
      started_at: now,
      updated_at: now
    )
    |> validate()
  end

  @spec touch_new_event(t(), AnsiblePlaybookEvent.t()) :: Query.t()
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
  def succeed(%__MODULE__{state: :running} = run) do
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
  def fail(%__MODULE__{state: :running} = run, exit_code)
      when is_nil(exit_code) or (is_integer(exit_code) and exit_code >= 0) do
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

  @spec interrupt(t()) :: Changeset.t(t())
  def interrupt(run) do
    now = DateTime.utc_now()

    run
    |> change(
      state: :interrupted,
      finished_at: now,
      updated_at: now
    )
    |> validate()
  end

  defp validate(changeset) do
    changeset
    |> update_change(:playbook, &trim/1)
    |> update_change(:user, &trim/1)
    |> validate_required([
      :playbook,
      :playbook_path,
      :digest,
      :vars,
      :server_id,
      :state,
      :started_at
    ])
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
