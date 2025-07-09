defmodule ArchiDep.Servers.Schemas.ServerGroup do
  @moduledoc """
  A group of servers that share common properties and configurations.
  """

  use ArchiDep, :schema

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers: list(Server.t()) | NotLoaded.t(),
          servers_count: non_neg_integer() | nil,
          expected_server_properties: ServerProperties.t() | nil | NotLoaded.t(),
          expected_server_properties_id: UUID.t() | nil,
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "classes" do
    field(:name, :binary)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean)
    field(:servers_count, :integer, virtual: true)
    belongs_to(:expected_server_properties, ServerProperties)
    has_many(:servers, Server, foreign_key: :group_id)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, start_date: start_date, end_date: end_date}, now),
    do:
      active and
        (is_nil(start_date) or now |> DateTime.to_date() |> Date.compare(start_date) != :lt) and
        (is_nil(end_date) or now |> DateTime.to_date() |> Date.compare(end_date) != :gt)

  @spec has_servers?(t()) :: boolean()
  def has_servers?(%__MODULE__{servers_count: count}), do: count != nil and count >= 1

  @spec update_expected_server_properties(t(), Types.server_properties()) :: Changeset.t(t())
  def update_expected_server_properties(group, data) do
    id = group.id
    now = DateTime.utc_now()

    data =
      Map.put(
        data,
        :expected_server_properties,
        Map.put(data.expected_server_properties, :id, id)
      )

    group
    |> cast(data, [])
    |> cast_assoc(:expected_server_properties, with: &ServerProperties.update/2)
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate_required([:expected_server_properties, :expected_server_properties_id])
  end
end
