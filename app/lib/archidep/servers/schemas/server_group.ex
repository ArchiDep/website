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
          servers_enabled: boolean(),
          servers: list(Server.t()) | NotLoaded.t(),
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
    field(:servers_enabled, :boolean)
    belongs_to(:expected_server_properties, ServerProperties, on_replace: :update)
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

  @spec allows_server_creation?(t(), DateTime.t()) :: boolean()
  def allows_server_creation?(%__MODULE__{servers_enabled: servers_enabled} = group, now),
    do: servers_enabled and active?(group, now)

  @spec expected_server_properties(t()) :: ServerProperties.t()

  def expected_server_properties(%__MODULE__{id: id, expected_server_properties: nil}),
    do: ServerProperties.blank(id)

  def expected_server_properties(%__MODULE__{expected_server_properties: props}), do: props

  @spec fetch_server_group(UUID.t()) :: {:ok, t()} | {:error, :server_group_not_found}
  def fetch_server_group(id),
    do:
      from(g in __MODULE__,
        left_join: esp in assoc(g, :expected_server_properties),
        where: g.id == ^id,
        preload: [expected_server_properties: esp]
      )
      |> Repo.one()
      |> truthy_or(:server_group_not_found)

  @spec refresh!(t(), map()) :: t()

  def refresh!(%__MODULE__{id: id, version: current_version} = group, %__MODULE__{
        id: id,
        name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        expected_server_properties: expected_server_properties,
        expected_server_properties_id: expected_server_properties_id,
        version: version,
        updated_at: updated_at
      })
      when version == current_version + 1 do
    %__MODULE__{
      group
      | name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        expected_server_properties: expected_server_properties,
        expected_server_properties_id: expected_server_properties_id,
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(%__MODULE__{id: id, version: current_version} = group, %{
        id: id,
        name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        version: version,
        updated_at: updated_at
      })
      when version == current_version + 1 do
    %__MODULE__{
      group
      | name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(%__MODULE__{id: id, version: current_version} = group, %{
        id: id,
        version: version
      })
      when version <= current_version do
    group
  end

  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_group} = fetch_server_group(id)
    fresh_group
  end

  @spec update_expected_server_properties(t(), Types.server_properties_data()) :: Changeset.t(t())
  def update_expected_server_properties(group, data) do
    now = DateTime.utc_now()

    group
    |> change(expected_server_properties: expected_server_properties(group))
    |> cast(
      %{
        expected_server_properties: data
      },
      []
    )
    |> cast_assoc(:expected_server_properties,
      with: fn props, params ->
        props |> ServerProperties.update(params) |> change(%{id: group.id})
      end
    )
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate_required([:expected_server_properties])
  end
end
