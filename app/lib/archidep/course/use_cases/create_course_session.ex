defmodule ArchiDep.Course.UseCases.CreateCourseSession do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Course.Events.CourseSessionCreated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Course.Types

  @spec validate_course_session(Authentication.t(), Types.course_session_data()) :: Changeset.t()
  def validate_course_session(auth, data) do
    authorize!(auth, Policy, :course, :validate_course_session, nil)
    CourseSession.new(data, Clock.now())
  end

  @spec create_course_session(Authentication.t(), Types.course_session_data()) ::
          {:ok, CourseSession.t()} | {:error, Changeset.t()}
  def create_course_session(auth, data) do
    authorize!(auth, Policy, :course, :create_course_session, nil)

    now = Clock.now()

    case Multi.new()
         |> Multi.insert(:course_session, CourseSession.new(data, now))
         |> Multi.insert(:stored_event, &course_session_created(auth, &1.course_session))
         |> Repo.transaction() do
      {:ok, %{course_session: course_session, stored_event: event}} ->
        :ok = PubSub.publish_course_session_created(event.data, StoredEvent.to_reference(event))
        {:ok, course_session}

      {:error, :course_session, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp course_session_created(auth, course_session),
    do:
      course_session
      |> CourseSessionCreated.new()
      |> new_event(auth, occurred_at: course_session.created_at)
      |> add_to_stream(course_session)
      |> initiated_by(auth)
end
