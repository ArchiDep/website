defmodule ArchiDep.Accounts.Schemas.UserAccount do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId

  @derive {Inspect, only: [:id, :username, :roles, :version]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t(),
          roles: list(String.t()),
          switch_edu_id: SwitchEduId.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @max_username_length 25

  schema "user_accounts" do
    field(:username, :string)
    field(:roles, {:array, Ecto.Enum}, values: [:root])
    belongs_to(:switch_edu_id, SwitchEduId)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @doc """
  Creates a new root user account from a Switch edu-ID login.
  """
  @spec new_root(SwitchEduId.t()) :: Changeset.t(__MODULE__.t())
  def new_root(switch_edu_id) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(%{username: switch_edu_id.first_name, roles: [:root]}, [
      :username,
      :roles
    ])
    |> validate_required([:username, :roles])
    |> change(
      id: id,
      switch_edu_id_id: switch_edu_id.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  @doc """
  Returns the event stream for the specified user account entity.
  """
  @spec event_stream(String.t() | __MODULE__.t()) :: String.t()
  def event_stream(id) when is_binary(id), do: "user-accounts:#{id}"
  def event_stream(%__MODULE__{id: id}), do: event_stream(id)

  defp validate(changeset),
    do:
      changeset
      |> validate_required([
        :id,
        :username,
        :roles,
        :version,
        :created_at,
        :updated_at
      ])
      |> validate_length(:username, max: @max_username_length)
      |> unique_constraint(:username, name: :user_accounts_unique_username_index)
end
