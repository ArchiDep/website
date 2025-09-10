defmodule ArchiDep.Course.Events.StudentConfigured do
  @moduledoc """
  Event representing the fact that a student has confirmed their configuration,
  which consists (for now) of the username that was suggested for them.
  """

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Student

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email,
    :username
  ]
  defstruct [
    :id,
    :name,
    :email,
    :username
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          username: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(member) do
    %Student{
      id: id,
      name: name,
      email: email,
      username: username
    } = member

    %__MODULE__{
      id: id,
      name: name,
      email: email,
      username: username
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentConfigured

    @spec event_stream(StudentConfigured.t()) :: String.t()
    def event_stream(%StudentConfigured{id: id}),
      do: "course:students:#{id}"

    @spec event_type(StudentConfigured.t()) :: atom()
    def event_type(_event), do: :"archidep/course/student-configured"
  end
end
