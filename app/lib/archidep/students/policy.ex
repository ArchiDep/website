defmodule ArchiDep.Students.Policy do
  use ArchiDep, :policy

  @impl Policy

  # Root users can validate classes.
  def authorize(
        :students,
        :validate_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create classes.
  def authorize(
        :students,
        :create_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list classes.
  def authorize(
        :students,
        :list_classes,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a class.
  def authorize(
        :students,
        :fetch_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing classes.
  def authorize(
        :students,
        :validate_existing_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update classes.
  def authorize(
        :students,
        :update_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can delete classes.
  def authorize(
        :students,
        :delete_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate students.
  def authorize(
        :students,
        :validate_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create students.
  def authorize(
        :students,
        :create_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can import students.
  def authorize(
        :students,
        :import_students,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list students.
  def authorize(
        :students,
        :list_students,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a student in class.
  def authorize(
        :students,
        :fetch_student_in_class,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update students.
  def authorize(
        :students,
        :update_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing students.
  def authorize(
        :students,
        :validate_existing_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can delete students.
  def authorize(
        :students,
        :delete_student,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
