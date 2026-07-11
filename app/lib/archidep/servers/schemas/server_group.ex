defmodule ArchiDep.Servers.Schemas.ServerGroup do
  @moduledoc """
  A group of servers that share common properties and can be
  activated/deactivated together.

  This is a read-view of the `classes` table owned (written) by the Course
  context.
  """

  use ArchiDep, :schema

  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties

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
          ssh_public_keys_to_install: list(String.t()),
          expected_server_properties: ServerProperties.t() | NotLoaded.t(),
          expected_server_properties_id: UUID.t(),
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

    field(:ssh_public_keys_to_install, {:array, :string},
      default: [],
      source: :teacher_ssh_public_keys
    )

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

  @spec where_server_group_active(atom(), Date.t()) :: Queryable.t()
  def where_server_group_active(binding, day),
    do:
      dynamic(
        [{^binding, g}],
        g.active and
          (is_nil(g.start_date) or g.start_date <= ^day) and
          (is_nil(g.end_date) or g.end_date >= ^day)
      )

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

  @spec refresh!(
          t(),
          ClassUpdated.t() | ClassExpectedServerPropertiesUpdated.t(),
          EventReference.t()
        ) :: t()
  def refresh!(group, event, %EventReference{version: version, occurred_at: occurred_at}),
    do:
      versioned_refresh(
        group,
        event,
        version,
        &fetch_server_group/1,
        &merge_refresh(&1, &2, version, occurred_at)
      )

  defp merge_refresh(
         %__MODULE__{id: id} = group,
         %ClassUpdated{
           id: id,
           name: name,
           start_date: start_date,
           end_date: end_date,
           active: active,
           servers_enabled: servers_enabled,
           teacher_ssh_public_keys: ssh_public_keys_to_install
         },
         version,
         updated_at
       ) do
    %__MODULE__{
      group
      | name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        ssh_public_keys_to_install: ssh_public_keys_to_install,
        version: version,
        updated_at: updated_at
    }
  end

  defp merge_refresh(
         %__MODULE__{id: id, expected_server_properties: expected_server_properties} = group,
         %ClassExpectedServerPropertiesUpdated{
           class: %{id: id},
           hostname: hostname,
           machine_id: machine_id,
           cpus: cpus,
           cores: cores,
           vcpus: vcpus,
           memory: memory,
           swap: swap,
           system: system,
           architecture: architecture,
           os_family: os_family,
           distribution: distribution,
           distribution_release: distribution_release,
           distribution_version: distribution_version
         },
         version,
         updated_at
       ) do
    %__MODULE__{
      group
      | expected_server_properties:
          ServerProperties.refresh(expected_server_properties, %{
            id: expected_server_properties.id,
            hostname: hostname,
            machine_id: machine_id,
            cpus: cpus,
            cores: cores,
            vcpus: vcpus,
            memory: memory,
            swap: swap,
            system: system,
            architecture: architecture,
            os_family: os_family,
            distribution: distribution,
            distribution_release: distribution_release,
            distribution_version: distribution_version
          }),
        version: version,
        updated_at: updated_at
    }
  end

  defp merge_refresh(_group, _incoming, _version, _updated_at), do: :refetch
end
