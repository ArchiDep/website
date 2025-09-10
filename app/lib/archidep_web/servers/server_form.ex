defmodule ArchiDepWeb.Servers.ServerForm do
  @moduledoc """
  Server form schema and changeset functions for creating and updating server
  data. This schema only validates the basic structure and types of the fields.
  Business validations are handled in the servers context.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias ArchiDepWeb.Servers.ServerPropertiesForm
  alias Ecto.Changeset

  @type t :: struct()

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:ip_address, :string)
    field(:username, :string)
    field(:ssh_port, :integer)
    field(:active, :boolean, default: true)
    field(:group_id, :binary_id)
    field(:app_username, :string)
    embeds_one(:expected_properties, ServerPropertiesForm, on_replace: :update)
  end

  @spec create_changeset(map) :: Changeset.t(Types.server_data())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{
      app_username: "archidep"
    }
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :app_username,
      :group_id
    ])
    |> cast_embed(:expected_properties, with: &ServerPropertiesForm.changeset/2)
    |> validate_required([:ip_address, :username, :active])
  end

  @spec to_create_data(t()) :: Types.server_data()
  def to_create_data(form),
    do:
      form
      |> Map.from_struct()
      |> Map.delete(:group_id)
      |> Map.put(
        :expected_properties,
        then(form.expected_properties, fn
          nil -> %{}
          properties -> ServerPropertiesForm.to_data(properties)
        end)
      )

  @spec update_changeset(Server.t(), map) :: Changeset.t(Types.server_data())
  def update_changeset(server, params \\ %{}) when is_struct(server, Server) and is_map(params) do
    %__MODULE__{
      name: server.name,
      ip_address: :inet.ntoa(server.ip_address.address),
      username: server.username,
      ssh_port: server.ssh_port,
      active: server.active,
      group_id: server.group_id,
      app_username: server.app_username,
      expected_properties: ServerPropertiesForm.from(server.expected_properties)
    }
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :app_username
    ])
    |> cast_embed(:expected_properties, with: &ServerPropertiesForm.changeset/2)
    |> validate_required([:ip_address, :username, :active])
  end

  @spec to_update_data(t()) :: Types.server_data()
  def to_update_data(form),
    do:
      form
      |> Map.from_struct()
      |> Map.put(:expected_properties, ServerPropertiesForm.to_data(form.expected_properties))
end
