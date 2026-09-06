defmodule ArchiDep.Course.Events.CourseSessionDeleted do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.CourseSession
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [:id, :date, :title]
  defstruct [:id, :date, :title]

  @type t :: %__MODULE__{
          id: UUID.t(),
          date: Date.t(),
          title: String.t()
        }

  @spec new(CourseSession.t()) :: t()
  def new(course_session) do
    %CourseSession{id: id, date: date, title: title} = course_session

    %__MODULE__{id: id, date: date, title: title}
  end

  defimpl Event do
    alias ArchiDep.Course.Events.CourseSessionDeleted

    @spec event_stream(CourseSessionDeleted.t()) :: String.t()
    def event_stream(%CourseSessionDeleted{id: id}), do: "course:sessions:#{id}"

    @spec event_type(CourseSessionDeleted.t()) :: atom()
    def event_type(_event), do: :"archidep/course/session-deleted"
  end
end
