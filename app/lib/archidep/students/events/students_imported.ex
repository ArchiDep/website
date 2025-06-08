defmodule ArchiDep.Students.Events.StudentsImported do
  use ArchiDep, :event

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :class_id,
    :students
  ]
  defstruct [
    :class_id,
    :academic_class,
    :students
  ]

  @type t :: %__MODULE__{
          class_id: UUID.t(),
          academic_class: String.t() | nil,
          students: list(%{name: String.t(), email: String.t()})
        }

  @spec new(Class.t(), String.t(), list(Student.t())) :: t()
  def new(%Class{id: class_id}, academic_class, students) do
    %__MODULE__{
      class_id: class_id,
      academic_class: academic_class,
      students: Enum.map(students, &Map.take(&1, [:name, :email]))
    }
  end

  defimpl Event do
    alias ArchiDep.Students.Events.StudentsImported

    def event_stream(%StudentsImported{class_id: class_id}),
      do: "classes:#{class_id}"

    def event_type(_event), do: :"archidep/students/students-imported"
  end
end
