defmodule ArchiDepWeb.Admin.Classes.ClassFormSshPublicKey do
  @moduledoc """
  Embedded schema representing an SSH public key.
  """

  use Ecto.Schema

  import ArchiDep.Helpers.SchemaHelpers
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{value: String.t()}

  @primary_key false
  embedded_schema do
    field(:value, :string, default: "")
  end

  @spec new(String.t()) :: t()
  def new(ssh_public_key), do: %__MODULE__{value: ssh_public_key}

  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(ssh_public_key, params \\ %{}) when is_map(params),
    do:
      ssh_public_key
      |> cast(params, [:value])
      |> update_change(:value, &trim/1)
      |> validate_required([:value])
      |> validate_format(:value, ~r/^ssh-(rsa|ed25519|ecdsa) /,
        message: "must start with 'ssh-rsa', 'ssh-ed25519' or 'ssh-ecdsa'"
      )
end
