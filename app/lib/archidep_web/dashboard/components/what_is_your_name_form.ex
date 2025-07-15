defmodule ArchiDepWeb.Dashboard.Components.WhatIsYourNameForm do
  use Ecto.Schema

  import ArchiDep.Helpers.ChangesetHelpers, only: [validate_not_nil: 2]
  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          username: String.t()
        }

  @fields ~w(username)a

  @primary_key false
  embedded_schema do
    field(:username, :string, default: "")
  end

  @spec changeset(Student.t(), map()) :: Changeset.t(t())
  def changeset(student, params \\ %{}) when is_map(params),
    do:
      %__MODULE__{}
      |> change(Map.take(student, @fields))
      |> cast(params, @fields)
      |> validate_not_nil(@fields)

  @spec to_data(t()) :: Types.student_config()
  def to_data(%__MODULE__{} = form), do: Map.take(form, @fields)
end
