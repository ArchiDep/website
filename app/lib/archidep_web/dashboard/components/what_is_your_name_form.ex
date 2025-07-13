defmodule ArchiDepWeb.Dashboard.Components.WhatIsYourNameForm do
  use Ecto.Schema

  import ArchiDep.Helpers.ChangesetHelpers, only: [validate_not_nil: 2]
  import Ecto.Changeset
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          username: String.t(),
          subdomain: String.t()
        }

  @fields ~w(username subdomain)a

  @primary_key false
  embedded_schema do
    field(:username, :string, default: "")
    field(:subdomain, :string, default: "")
  end

  @spec changeset(ServerGroupMember.t(), map()) :: Changeset.t(t())
  def changeset(member, params \\ %{}) when is_map(params),
    do:
      %__MODULE__{}
      |> change(Map.take(member, @fields))
      |> cast(params, @fields)
      |> validate_not_nil(@fields)

  @spec to_data(t()) :: Types.server_group_member_config()
  def to_data(%__MODULE__{} = form), do: Map.take(form, @fields)
end
