defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookEvent do
  @moduledoc """
  An event that occurred during the execution of an Ansible playbook run on a
  server. This schema captures the details of the event, including its name,
  action, whether it changed the state of the server, and any associated data.
  """

  use ArchiDep, :schema

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Ecto.UUID

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          run: AnsiblePlaybookRun.t() | NotLoaded,
          run_id: UUID.t(),
          name: String.t(),
          action: String.t() | nil,
          changed: boolean(),
          data: %{String.t() => term()},
          task_name: String.t() | nil,
          task_id: String.t() | nil,
          task_started_at: DateTime.t() | nil,
          task_ended_at: DateTime.t() | nil,
          occurred_at: DateTime.t()
        }

  schema "ansible_playbook_events" do
    belongs_to(:run, AnsiblePlaybookRun, type: :binary_id)
    field(:name, :string)
    field(:action, :string)
    field(:changed, :boolean, default: false)
    field(:data, :map)
    field(:task_name, :string)
    field(:task_id, :string)
    field(:task_started_at, :utc_datetime_usec)
    field(:task_ended_at, :utc_datetime_usec)
    field(:occurred_at, :utc_datetime_usec)
    field(:created_at, :utc_datetime_usec)
  end

  @spec new(%{String.t() => term()}, AnsiblePlaybookRun.t()) :: Changeset.t(t())
  def new(data, run) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> change(
      id: id,
      run_id: run.id,
      name: binary_or(data, ["_event"], "_"),
      action: binary_or(data, ["hosts", "archidep", "action"], nil),
      changed: boolean_or(data, ["hosts", "archidep", "changed"], false),
      data: data,
      task_name: binary_or(data, ["task", "name"], nil),
      task_id: binary_or(data, ["task", "id"], nil),
      task_started_at: utc_datetime_or_nil(data, ["task", "start"]),
      task_ended_at: utc_datetime_or_nil(data, ["task", "end"]),
      occurred_at: utc_datetime_or_nil(data, ["_timestamp"]) || now,
      created_at: now
    )
    |> validate()
  end

  defp validate(changeset) do
    changeset
    |> update_change(:name, &trim/1)
    |> update_change(:name, &truncate(&1, 255))
    |> update_change(:action, &trim_to_nil/1)
    |> update_change(:action, &truncate(&1, 255))
    |> update_change(:task_name, &trim_to_nil/1)
    |> update_change(:task_name, &truncate(&1, 255))
    |> update_change(:task_id, &trim_to_nil/1)
    |> update_change(:task_id, &truncate(&1, 255))
    |> validate_required([:run_id, :name, :data, :occurred_at])
    |> validate_length(:name, max: 255)
    |> validate_length(:action, max: 255)
    |> validate_length(:task_name, max: 255)
    |> validate_length(:task_id, max: 255)
  end

  defp binary_or(data, path, default), do: binary_or(get_in(data, path), default)

  defp binary_or(value, default)
       when is_binary(value) and (is_binary(default) or is_nil(default)),
       do: value

  defp binary_or(_value, default) when is_binary(default) or is_nil(default), do: default

  defp boolean_or(data, path, default), do: boolean_or(get_in(data, path), default)

  defp boolean_or(value, default)
       when is_boolean(value) and (is_boolean(default) or is_nil(default)),
       do: value

  defp boolean_or(_value, default) when is_boolean(default) or is_nil(default), do: default

  defp utc_datetime_or_nil(data, path) do
    utc_datetime_or_nil(get_in(data, path))
  end

  def utc_datetime_or_nil(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, 0} -> datetime
      _anything_else -> nil
    end
  end

  def utc_datetime_or_nil(_value), do: nil
end
