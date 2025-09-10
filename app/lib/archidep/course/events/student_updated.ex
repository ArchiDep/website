defmodule ArchiDep.Course.Events.StudentUpdated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email,
    :academic_class,
    :username,
    :domain,
    :active,
    :servers_enabled,
    :class
  ]
  defstruct [
    :id,
    :name,
    :email,
    :academic_class,
    :username,
    :domain,
    :active,
    :servers_enabled,
    :class
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          username: String.t(),
          domain: String.t(),
          active: boolean(),
          servers_enabled: boolean(),
          class: %{
            id: UUID.t(),
            name: String.t()
          }
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name,
      email: email,
      academic_class: academic_class,
      username: username,
      domain: domain,
      active: active,
      servers_enabled: servers_enabled,
      class: class
    } = student

    %Class{
      id: class_id,
      name: class_name
    } = class

    %__MODULE__{
      id: id,
      name: name,
      email: email,
      academic_class: academic_class,
      username: username,
      domain: domain,
      active: active,
      servers_enabled: servers_enabled,
      class: %{
        id: class_id,
        name: class_name
      }
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentUpdated

    @spec event_stream(StudentUpdated.t()) :: String.t()
    def event_stream(%StudentUpdated{id: id}),
      do: "course:students:#{id}"

    @spec event_type(StudentUpdated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/student-updated"
  end
end
