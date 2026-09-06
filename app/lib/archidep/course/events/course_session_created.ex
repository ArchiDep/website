defmodule ArchiDep.Course.Events.CourseSessionCreated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.CourseSession
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [:id, :date, :title, :done, :due, :next]
  defstruct [:id, :date, :title, :done, :due, :next]

  @type t :: %__MODULE__{
          id: UUID.t(),
          date: Date.t(),
          title: String.t(),
          done: [pos_integer()],
          due: [pos_integer()],
          next: [pos_integer()]
        }

  @spec new(CourseSession.t()) :: t()
  def new(course_session) do
    %CourseSession{id: id, date: date, title: title, done: done, due: due, next: next} =
      course_session

    %__MODULE__{id: id, date: date, title: title, done: done, due: due, next: next}
  end

  defimpl Event do
    alias ArchiDep.Course.Events.CourseSessionCreated

    @spec event_stream(CourseSessionCreated.t()) :: String.t()
    def event_stream(%CourseSessionCreated{id: id}), do: "course:sessions:#{id}"

    @spec event_type(CourseSessionCreated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/session-created"
  end
end
