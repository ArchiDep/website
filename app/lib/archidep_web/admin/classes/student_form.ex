defmodule ArchiDepWeb.Admin.Classes.StudentForm do
  @moduledoc """
  Student form schema and changeset functions for creating and updating student
  data. This schema only validates the basic structure and types of the fields.
  Business validations are handled in the course context.
  """

  use Ecto.Schema

  import ArchiDep.Helpers.ChangesetHelpers, only: [validate_not_nil: 2]
  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          username: String.t(),
          domain: String.t(),
          active: boolean(),
          servers_enabled: boolean()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:email, :string, default: "")
    field(:academic_class, :string)
    field(:username, :string, default: "")
    field(:domain, :string, default: "")
    field(:active, :boolean, default: true)
    field(:servers_enabled, :boolean, default: false)
  end

  @spec create_changeset(map()) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [
      :name,
      :email,
      :academic_class,
      :username,
      :domain,
      :active,
      :servers_enabled
    ])
    |> validate_not_nil([:name, :email, :username, :domain, :active, :servers_enabled])
  end

  @spec update_changeset(Student.t(), map()) :: Changeset.t(t())
  def update_changeset(student, params \\ %{}) when is_map(params) do
    %__MODULE__{
      name: student.name,
      email: student.email,
      academic_class: student.academic_class,
      username: student.username,
      domain: student.domain,
      active: student.active,
      servers_enabled: student.servers_enabled
    }
    |> cast(params, [
      :name,
      :email,
      :academic_class,
      :username,
      :domain,
      :active,
      :servers_enabled
    ])
    |> validate_not_nil([:name, :email, :username, :domain, :active, :servers_enabled])
  end

  @spec to_student_data(t()) :: Types.student_data()
  def to_student_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      email: form.email,
      academic_class: form.academic_class,
      username: form.username,
      domain: form.domain,
      active: form.active,
      servers_enabled: form.servers_enabled
    }
  end
end
