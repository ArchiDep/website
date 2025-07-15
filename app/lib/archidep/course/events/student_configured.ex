defmodule ArchiDep.Course.Events.StudentConfigured do
  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Student

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :username
  ]
  defstruct [
    :id,
    :username
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(member) do
    %Student{
      id: id,
      username: username
    } = member

    %__MODULE__{
      id: id,
      username: username
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentConfigured

    def event_stream(%StudentConfigured{id: id}),
      do: "students:#{id}"

    def event_type(_event), do: :"archidep/course/student-configured"
  end
end
