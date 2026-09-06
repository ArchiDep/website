defmodule ArchiDep.Course.UseCases.DeleteCourseSession do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Course.Events.CourseSessionDeleted
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession

  @spec delete_course_session(Authentication.t(), UUID.t()) ::
          :ok | {:error, :course_session_not_found}
  def delete_course_session(auth, id) do
    with :ok <- validate_uuid(id, :course_session_not_found),
         {:ok, course_session} <- CourseSession.fetch_course_session(id) do
      authorize!(auth, Policy, :course, :delete_course_session, course_session)

      now = Clock.now()

      {:ok, %{stored_event: event}} =
        Multi.new()
        |> Multi.delete(:course_session, CourseSession.delete(course_session))
        |> Multi.insert(:stored_event, &course_session_deleted(auth, &1.course_session, now))
        |> Repo.transaction()

      :ok = PubSub.publish_course_session_deleted(event.data, StoredEvent.to_reference(event))
      :ok
    end
  end

  defp course_session_deleted(auth, course_session, now),
    do:
      course_session
      |> CourseSessionDeleted.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(course_session)
      |> initiated_by(auth)
end
