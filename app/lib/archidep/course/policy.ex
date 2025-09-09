defmodule ArchiDep.Course.Policy do
  @moduledoc """
  Authorization policy for class- and student-related actions.
  """

  use ArchiDep, :policy

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User

  @impl Policy

  # Root users can perform any action.
  def authorize(
        :course,
        _action,
        %Authentication{root: true},
        _params
      ),
      do: true

  # Any user can fetch their authenticated student.
  def authorize(
        :course,
        :fetch_authenticated_student,
        %Authentication{},
        _params
      ),
      do: true

  # Students can confirm their own username.
  def authorize(
        :course,
        :configure_student,
        %Authentication{principal_id: principal_id, root: false},
        {%User{id: principal_id, student_id: student_id},
         %Student{id: student_id, user_id: principal_id}}
      ),
      do: true

  def authorize(_context, _action, _auth, _params), do: false
end
