defmodule ArchiDepWeb.Admin.Classes.ClassFormSshPublicKey do
  use Ecto.Schema

  @type t :: %{value: String.t()}

  @primary_key false
  embedded_schema do
    field(:value, :string, default: "")
  end

  def changeset(ssh_public_key, params \\ %{}) when is_map(params),
    do:
      ssh_public_key
      |> Ecto.Changeset.cast(params, [:value])
      |> Ecto.Changeset.validate_required([:value])
      |> Ecto.Changeset.validate_format(:value, ~r/^ssh-(rsa|ed25519|ecdsa) /,
        message: "must start with 'ssh-rsa', 'ssh-ed25519' ' or 'ssh-ecdsa'"
      )
end
