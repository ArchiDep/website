defmodule ArchiDep.Students.Events.StudentsImported do
  use ArchiDep, :event

  alias ArchiDep.Students.Schemas.Class
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :class_id,
    :number_of_students
  ]
  defstruct [
    :class_id,
    :academic_class,
    :number_of_students
  ]

  @type t :: %__MODULE__{
          class_id: UUID.t(),
          academic_class: String.t() | nil,
          number_of_students: non_neg_integer()
        }

  @spec new(Class.t(), String.t(), non_neg_integer()) :: t()
  def new(%Class{id: class_id}, academic_class, number_of_students) do
    %__MODULE__{
      class_id: class_id,
      academic_class: academic_class,
      number_of_students: number_of_students
    }
  end

  defimpl Event do
    alias ArchiDep.Students.Events.StudentsImported

    def event_stream(%StudentsImported{class_id: class_id}),
      do: "classes:#{class_id}"

    def event_type(_event), do: :"archidep/students/students-imported"
  end
end
