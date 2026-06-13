defmodule ArchiDep.Course.ReadStudentsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.CourseTestHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test.
  @now ~U[2024-03-15 10:30:00.000000Z]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      list_students: protect({Context, :list_students, 2}, Behaviour),
      fetch_authenticated_student: protect({Context, :fetch_authenticated_student, 1}, Behaviour),
      fetch_student_in_class: protect({Context, :fetch_student_in_class, 3}, Behaviour)
    }
  end

  describe "list_students/2" do
    test "list the students of a class, ordered by name", %{list_students: list_students} do
      %Class{} = class = CourseFactory.insert(:class)

      # Inserted out of order to prove the query sorts by name rather than
      # returning insertion order. Unlinked (no user) so their loaded shape is
      # deterministic.
      %Student{} =
        charlie = CourseFactory.insert(:student, class: class, name: "Charlie", user: nil)

      %Student{} = alice = CourseFactory.insert(:student, class: class, name: "Alice", user: nil)
      %Student{} = bob = CourseFactory.insert(:student, class: class, name: "Bob", user: nil)

      # A student in another class must not leak into this list.
      CourseFactory.insert(:student, name: "Zoe", user: nil)

      auth = Factory.build(:authentication, root: true)

      # `list_students_in_class/1` preloads the class without its expected server
      # properties, so the expected students carry the inserted class with that
      # association reset to unloaded.
      listed_class = %Class{
        class
        | expected_server_properties: not_loaded(:expected_server_properties, Class)
      }

      assert list_students.(auth, class) == [
               %Student{alice | class: listed_class},
               %Student{bob | class: listed_class},
               %Student{charlie | class: listed_class}
             ]

      assert_no_stored_events!()
    end

    test "list no students for an empty class", %{list_students: list_students} do
      class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: true)

      assert list_students.(auth, class) == []

      assert_no_stored_events!()
    end

    test "a non-root user cannot list the students of a class", %{list_students: list_students} do
      class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> list_students.(auth, class) end

      assert_no_stored_events!()
    end
  end

  describe "fetch_authenticated_student/1" do
    test "fetch the student linked to the authenticated account", %{
      fetch_authenticated_student: fetch_authenticated_student
    } do
      {student, account, auth} = register_student()

      assert fetch_authenticated_student.(auth) == {:ok, authenticated_student(student, account)}

      assert_no_stored_events!()
    end

    test "an account not linked to a student is not a student", %{
      fetch_authenticated_student: fetch_authenticated_student
    } do
      # A root account has no linked student.
      account = AccountsFactory.insert(:user_account, root: true, active: true)
      auth = Factory.build(:authentication, principal_id: account.id, root: true)

      assert fetch_authenticated_student.(auth) == {:error, :not_a_student}

      assert_no_stored_events!()
    end

    test "a principal with no account is not a student", %{
      fetch_authenticated_student: fetch_authenticated_student
    } do
      auth = Factory.build(:authentication, root: false)

      assert fetch_authenticated_student.(auth) == {:error, :not_a_student}

      assert_no_stored_events!()
    end
  end

  describe "fetch_student_in_class/3" do
    test "fetch a student in a class", %{fetch_student_in_class: fetch_student_in_class} do
      class = CourseFactory.insert(:class)
      student = CourseFactory.insert(:student, class: class, user: nil)
      auth = Factory.build(:authentication, root: true)

      # The query preloads the class with its expected server properties and the
      # (absent) user, matching the unlinked factory student exactly.
      assert fetch_student_in_class.(auth, class.id, student.id) == {:ok, student}

      assert_no_stored_events!()
    end

    test "a student in another class is reported as not found", %{
      fetch_student_in_class: fetch_student_in_class
    } do
      other_class = CourseFactory.insert(:class)
      student = CourseFactory.insert(:student, user: nil)
      auth = Factory.build(:authentication, root: true)

      assert fetch_student_in_class.(auth, other_class.id, student.id) ==
               {:error, :student_not_found}

      assert_no_stored_events!()
    end

    test "a student that does not exist is reported as not found", %{
      fetch_student_in_class: fetch_student_in_class
    } do
      class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: true)

      assert fetch_student_in_class.(auth, class.id, Ecto.UUID.generate()) ==
               {:error, :student_not_found}

      assert_no_stored_events!()
    end

    test "a non-root user gets not found rather than access denied", %{
      fetch_student_in_class: fetch_student_in_class
    } do
      # The authorization failure is masked as `:student_not_found` so it does
      # not leak the existence of a student the caller may not see.
      class = CourseFactory.insert(:class)
      student = CourseFactory.insert(:student, class: class, user: nil)
      auth = Factory.build(:authentication, root: false)

      assert fetch_student_in_class.(auth, class.id, student.id) ==
               {:error, :student_not_found}

      assert_no_stored_events!()
    end
  end

  # Builds the exact student `fetch_authenticated_student/1` is expected to
  # return: `fetch_student_for_user_account_id/1` preloads the class with its
  # expected server properties and the linked account as a course `User`
  # (without its nested student), so the linked-student fixture (read here via
  # `Student.fetch_student/1`) has those two associations reshaped to match.
  defp authenticated_student(%Student{} = student, account) do
    class =
      Repo.one!(
        from c in Class, where: c.id == ^student.class_id, preload: :expected_server_properties
      )

    user = %User{
      __meta__: loaded(User, "user_accounts"),
      id: account.id,
      username: account.username,
      active: account.active,
      student_id: student.id,
      student: not_loaded(:student, User),
      version: account.version,
      created_at: account.created_at,
      updated_at: account.updated_at
    }

    %Student{student | class: class, user: user}
  end
end
