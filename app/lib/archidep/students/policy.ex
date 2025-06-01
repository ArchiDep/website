defmodule ArchiDep.Students.Policy do
  use ArchiDep, :policy

  @impl Policy

  # Root users can validate classes.
  def authorize(
        :students,
        :validate_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create classes.
  def authorize(
        :students,
        :create_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list classes.
  def authorize(
        :students,
        :list_classes,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a class.
  def authorize(
        :students,
        :fetch_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing classes.
  def authorize(
        :students,
        :validate_existing_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update classes.
  def authorize(
        :students,
        :update_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate students.
  def authorize(
        :students,
        :validate_student,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create students.
  def authorize(
        :students,
        :create_student,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list students.
  def authorize(
        :students,
        :list_students,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a student in class.
  def authorize(
        :students,
        :fetch_student_in_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update students.
  def authorize(
        :students,
        :update_student,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing students.
  def authorize(
        :students,
        :validate_existing_student,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
