defmodule ArchiDep.Course.Events.StudentsImportedInClass do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :class_id,
    :class_name,
    :academic_class,
    :domain,
    :number_of_students
  ]
  defstruct [
    :class_id,
    :class_name,
    :academic_class,
    :domain,
    :number_of_students
  ]

  @type t :: %__MODULE__{
          class_id: UUID.t(),
          class_name: String.t(),
          academic_class: String.t() | nil,
          domain: String.t(),
          number_of_students: non_neg_integer()
        }

  @spec new(Class.t(), String.t() | nil, String.t(), non_neg_integer()) :: t()
  def new(%Class{id: class_id, name: class_name}, academic_class, domain, number_of_students) do
    %__MODULE__{
      class_id: class_id,
      class_name: class_name,
      academic_class: academic_class,
      domain: domain,
      number_of_students: number_of_students
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentsImportedInClass

    @spec event_stream(StudentsImportedInClass.t()) :: String.t()
    def event_stream(%StudentsImportedInClass{class_id: class_id}),
      do: "course:classes:#{class_id}"

    @spec event_type(StudentsImportedInClass.t()) :: atom()
    def event_type(_event), do: :"archidep/course/students-imported-in-class"
  end
end
