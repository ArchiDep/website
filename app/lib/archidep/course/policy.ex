defmodule ArchiDep.Course.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User

  @impl Policy

  # Root users can validate classes.
  def authorize(
        :course,
        :validate_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create classes.
  def authorize(
        :course,
        :create_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list classes.
  def authorize(
        :course,
        :list_classes,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a class.
  def authorize(
        :course,
        :fetch_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing classes.
  def authorize(
        :course,
        :validate_existing_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update classes.
  def authorize(
        :course,
        :update_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can delete classes.
  def authorize(
        :course,
        :delete_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate students.
  def authorize(
        :course,
        :validate_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create students.
  def authorize(
        :course,
        :create_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can import students.
  def authorize(
        :course,
        :import_students,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list students.
  def authorize(
        :course,
        :list_students,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Any user can fetch their authenticated student.
  def authorize(
        :course,
        :fetch_authenticated_student,
        %Authentication{},
        _params
      ),
      do: true

  # Root users can fetch a student in class.
  def authorize(
        :course,
        :fetch_student_in_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update students.
  def authorize(
        :course,
        :update_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing students.
  def authorize(
        :course,
        :validate_existing_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Students can confirm their own username.
  def authorize(
        :course,
        :configure_student,
        %Authentication{principal_id: principal_id, roles: roles},
        {%User{id: principal_id, student_id: student_id},
         %Student{id: student_id, user_id: principal_id}}
      ),
      do: Enum.member?(roles, :student)

  # Root users can delete students.
  def authorize(
        :course,
        :delete_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
