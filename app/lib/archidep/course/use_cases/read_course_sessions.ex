defmodule ArchiDep.Course.UseCases.ReadCourseSessions do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.Events.Store.EventReference

  @messages [:course_session_created, :course_session_updated, :course_session_deleted]

  # Nothing to authorize: how far the course has got is public, and the command
  # use cases of this context authorize because they act on a class, a student
  # or a session, none of which this touches.
  @spec course_sessions() :: [Session.t()]
  def course_sessions,
    do: Enum.map(CourseSession.list_course_sessions(), &CourseSession.to_session/1)

  @spec list_course_sessions(Authentication.t()) :: [CourseSession.t()]
  def list_course_sessions(auth) do
    authorize!(auth, Policy, :course, :list_course_sessions, nil)
    CourseSession.list_course_sessions()
  end

  # Subscribing to the sessions topic grants no access beyond what
  # `list_course_sessions/1` already authorized, so subscribing takes no
  # authentication and skips the authorization the command use cases perform.
  @spec subscribe_course_sessions() :: :ok
  def subscribe_course_sessions, do: PubSub.subscribe_course_sessions()

  # The list is re-read rather than reconciled in memory. Placing a session in
  # it takes the order the sessions were taught, which `CourseSession` derives
  # from the rows; a consumer reconciling the list would hold a second copy of
  # that rule, and would be right only for as long as it had seen every event.
  # Re-reading a dozen rows on an edit made by hand costs nothing and cannot
  # disagree with what was stored. It goes through the public context boundary
  # so the consuming LiveView sees it as an ordinary context read, authorized
  # and mockable.
  @spec refresh_course_sessions(Authentication.t(), [CourseSession.t()], term()) ::
          {:ok, [CourseSession.t()]} | :ignore
  def refresh_course_sessions(auth, course_sessions, {message, _event, %EventReference{}})
      when is_list(course_sessions) and message in @messages,
      do: {:ok, ArchiDep.Course.list_course_sessions(auth)}

  def refresh_course_sessions(_auth, _course_sessions, _message), do: :ignore
end
