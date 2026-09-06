defmodule ArchiDep.Course.UseCases.UpdateCourseSession do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Course.Events.CourseSessionUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Course.Types

  @spec validate_existing_course_session(
          Authentication.t(),
          UUID.t(),
          Types.course_session_data()
        ) :: {:ok, Changeset.t()} | {:error, :course_session_not_found}
  def validate_existing_course_session(auth, id, data) do
    with :ok <- validate_uuid(id, :course_session_not_found),
         {:ok, course_session} <- CourseSession.fetch_course_session(id) do
      authorize!(auth, Policy, :course, :validate_existing_course_session, course_session)
      {:ok, CourseSession.update(course_session, data, Clock.now())}
    end
  end

  @spec update_course_session(Authentication.t(), UUID.t(), Types.course_session_data()) ::
          {:ok, CourseSession.t()}
          | {:error, Changeset.t()}
          | {:error, :course_session_not_found}
  def update_course_session(auth, id, data) do
    with :ok <- validate_uuid(id, :course_session_not_found),
         {:ok, course_session} <- CourseSession.fetch_course_session(id) do
      authorize!(auth, Policy, :course, :update_course_session, course_session)

      now = Clock.now()

      case Multi.new()
           |> Multi.update(:course_session, CourseSession.update(course_session, data, now))
           |> Multi.insert(:stored_event, &course_session_updated(auth, &1.course_session))
           |> Repo.transaction() do
        {:ok, %{course_session: updated_course_session, stored_event: event}} ->
          :ok = PubSub.publish_course_session_updated(event.data, StoredEvent.to_reference(event))
          {:ok, updated_course_session}

        {:error, :course_session, changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  defp course_session_updated(auth, course_session),
    do:
      course_session
      |> CourseSessionUpdated.new()
      |> new_event(auth, occurred_at: course_session.updated_at)
      |> add_to_stream(course_session)
      |> initiated_by(auth)
end
