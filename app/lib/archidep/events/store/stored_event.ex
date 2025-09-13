defmodule ArchiDep.Events.Store.StoredEvent do
  @moduledoc """
  A business event that has occurred and has been stored into the database.
  """

  use Ecto.Schema

  import ArchiDep.Helpers.PipeHelpers
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Repo
  alias Ecto.Changeset
  alias Ecto.UUID

  @primary_key {:id, :binary_id, []}
  @timestamps_opts [type: :utc_datetime_usec]

  @type t(data) :: %__MODULE__{
          id: UUID.t(),
          stream: String.t(),
          version: pos_integer(),
          type: String.t(),
          data: data,
          meta: map,
          initiator: String.t() | nil,
          causation_id: UUID.t(),
          correlation_id: UUID.t(),
          occurred_at: DateTime.t(),
          entity: struct | nil
        }

  @type changeset(data) :: Changeset.t(t(data))

  @type options ::
          list({:caused_by, t(struct) | EventReference.t() | nil} | {:occurred_at, DateTime.t()})

  schema "events" do
    field(:stream, :string)
    field(:version, :integer)
    field(:type, :string)
    field(:data, :map)
    field(:meta, :map)
    field(:initiator, :string)
    field(:causation_id, :binary_id)
    field(:correlation_id, :binary_id)
    field(:occurred_at, :utc_datetime_usec)
    field(:entity, :map, virtual: true)
  end

  @spec fetch_event(UUID.t()) :: {:ok, __MODULE__.t(map)} | {:error, :event_not_found}
  def fetch_event(id),
    do:
      from(se in __MODULE__, where: se.id == ^id)
      |> Repo.one()
      |> truthy_or(:event_not_found)

  @doc """
  Creates a new business event with the specified data and metadata.

  A cause may be specified as an option to set the causation and correlation
  IDs. The causation ID is the ID of the event that directly caused this event
  to occur, while the correlation ID is the ID of the root event in a chain of
  related events.
  """
  @spec new(map, map, options) :: __MODULE__.changeset(struct)
  def new(data, meta, opts \\ []) when is_map(data) and is_map(meta) and is_list(opts) do
    id = UUID.generate()
    occurred_at = Keyword.get_lazy(opts, :occurred_at, &DateTime.utc_now/0)
    caused_by = Keyword.get(opts, :caused_by) || %{}

    %__MODULE__{}
    |> cast(
      %{
        id: id,
        data: data,
        meta: meta,
        causation_id: Map.get(caused_by, :id, id),
        correlation_id: Map.get(caused_by, :correlation_id, id),
        occurred_at: occurred_at
      },
      [:id, :data, :meta, :causation_id, :correlation_id, :occurred_at]
    )
    |> validate_required([:id, :data, :meta, :causation_id, :correlation_id, :occurred_at])
  end

  @doc """
  Sets the stream, version and type of a business event.
  """
  @spec stream(__MODULE__.changeset(map), String.t(), pos_integer, String.t()) ::
          __MODULE__.changeset(map)
  def stream(changeset, stream, version, type),
    do:
      changeset
      |> cast(%{stream: stream, version: version, type: type}, [:stream, :version, :type])
      |> validate_required([:stream, :version, :type])
      |> validate_number(:version, greater_than_or_equal_to: 1)

  @doc """
  Sets the initiator of a business event.
  """
  @spec initiated_by(__MODULE__.changeset(map), String.t()) :: __MODULE__.changeset(map)
  def initiated_by(changeset, initiator),
    do: cast(changeset, %{initiator: initiator}, [:initiator])

  @spec to_insert_data(t(struct)) :: map
  def to_insert_data(%__MODULE__{} = event) do
    %{
      id: event.id,
      stream: event.stream,
      version: event.version,
      type: event.type,
      data: event.data,
      meta: event.meta,
      initiator: event.initiator,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id,
      occurred_at: event.occurred_at
    }
  end

  @spec to_reference(t(map)) :: EventReference.t()
  def to_reference(%__MODULE__{
        id: id,
        causation_id: causation_id,
        correlation_id: correlation_id
      }),
      do: %EventReference{
        id: id,
        causation_id: causation_id,
        correlation_id: correlation_id
      }
end
