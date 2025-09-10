defmodule ArchiDep.Course.Events.StudentDeleted do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email
  ]
  defstruct [
    :id,
    :name,
    :email
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name,
      email: email
    } = student

    %__MODULE__{
      id: id,
      name: name,
      email: email
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentDeleted

    @spec event_stream(StudentDeleted.t()) :: String.t()
    def event_stream(%StudentDeleted{id: id}),
      do: "course:students:#{id}"

    @spec event_type(StudentDeleted.t()) :: atom()
    def event_type(_event), do: :"archidep/course/student-deleted"
  end
end
