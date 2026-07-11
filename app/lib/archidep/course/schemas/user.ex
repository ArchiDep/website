defmodule ArchiDep.Course.Schemas.User do
  @moduledoc """
  A user of the application who can log in to access the course and track
  servers. A user may be a student enrolled in a class.

  This is a read-view of the `user_accounts` table owned (written) by the
  Accounts context.
  """

  use ArchiDep, :schema

  alias ArchiDep.Authentication
  alias ArchiDep.Course.Schemas.Student

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t(),
          active: boolean(),
          student: Student.t() | nil | NotLoaded.t(),
          student_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_accounts" do
    field(:username, :string)
    field(:active, :boolean)
    belongs_to(:student, Student)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec fetch_user(UUID.t()) :: {:ok, t()} | {:error, :user_not_found}
  def fetch_user(id),
    do:
      from(u in __MODULE__,
        left_join: s in assoc(u, :student),
        left_join: sc in assoc(s, :class),
        where: u.id == ^id,
        preload: [student: {s, class: sc}]
      )
      |> Repo.one()
      |> truthy_or(:user_not_found)

  @spec fetch_authenticated(Authentication.t()) :: {:ok, t()} | {:error, :not_a_user}
  def fetch_authenticated(auth),
    do:
      from(u in __MODULE__,
        left_join: s in assoc(u, :student),
        left_join: sc in assoc(s, :class),
        where: u.id == ^auth.principal_id,
        preload: [student: {s, class: sc}]
      )
      |> Repo.one()
      |> truthy_or(:not_a_user)
end
