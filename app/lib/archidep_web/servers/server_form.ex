defmodule ArchiDepWeb.Servers.ServerForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:ip_address, :string)
    field(:username, :string)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :ip_address, :username])
    |> validate_required([:ip_address, :username])
  end

  @spec update_changeset(Server.t(), map) :: Changeset.t(t())
  def update_changeset(server, params \\ %{}) when is_struct(server, Server) and is_map(params) do
    %__MODULE__{
      name: server.name,
      ip_address: server.ip_address,
      username: server.username
    }
    |> cast(params, [:name, :ip_address, :username])
    |> validate_required([:ip_address, :username])
  end

  @spec to_create_server_data(t()) :: Types.create_server_data()
  def to_create_server_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      ip_address: form.ip_address,
      username: form.username
    }
  end
end
