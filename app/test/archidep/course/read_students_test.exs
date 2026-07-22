defmodule ArchiDep.Course.ReadStudentsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.CourseTestHelpers
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
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
      fetch_student_in_class: protect({Context, :fetch_student_in_class, 3}, Behaviour),
      subscribe_student: protect({Context, :subscribe_student, 1}, Behaviour),
      refresh_student: protect({Context, :refresh_student, 2}, Behaviour),
      subscribe_class_students: protect({Context, :subscribe_class_students, 1}, Behaviour),
      refresh_class_students: protect({Context, :refresh_class_students, 4}, Behaviour),
      subscribe_student_detail: protect({Context, :subscribe_student_detail, 1}, Behaviour),
      refresh_student_detail: protect({Context, :refresh_student_detail, 2}, Behaviour)
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
      %Student{} = student = CourseFactory.insert(:student, user: nil)
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

  describe "subscribe_student/1" do
    test "subscribes the calling process to the student's topic", %{
      subscribe_student: subscribe_student
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      assert subscribe_student.(student) == :ok

      updated = %Student{student | name: "Renamed", version: student.version + 1}
      event = StudentUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)
      :ok = PubSub.publish_student_updated(updated, event, reference)

      assert_receive {:student_updated, ^event, ^reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_student/2" do
    test "reconciles the student from a student-updated message", %{
      refresh_student: refresh_student
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      updated = %Student{student | name: "Renamed", version: student.version + 1}
      event = StudentUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_student.(student, {:student_updated, event, reference}) ==
               {:ok, Student.refresh!(student, event, reference)}

      assert_no_stored_events!()
    end

    test "reconciles the student from a student-configured message", %{
      refresh_student: refresh_student
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      configured = %Student{student | username_confirmed: true, version: student.version + 1}
      event = StudentConfigured.new(configured)
      reference = EventsFactory.build(:event_reference, version: configured.version)

      assert refresh_student.(student, {:student_updated, event, reference}) ==
               {:ok, Student.refresh!(student, event, reference)}

      assert_no_stored_events!()
    end

    test "ignores a student-updated message for another student", %{
      refresh_student: refresh_student
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)
      %Student{} = other = CourseFactory.build(:student, user: nil)

      event = StudentUpdated.new(%Student{other | version: other.version + 1})
      reference = EventsFactory.build(:event_reference, version: other.version + 1)

      assert refresh_student.(student, {:student_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end

    test "ignores a message shape it does not handle", %{refresh_student: refresh_student} do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      assert refresh_student.(student, {:student_deleted, student}) == :ignore
      assert refresh_student.(student, :unrelated) == :ignore

      assert_no_stored_events!()
    end

    test "ignores any message when there is no student to reconcile", %{
      refresh_student: refresh_student
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      updated = %Student{student | name: "Renamed", version: student.version + 1}
      event = StudentUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_student.(nil, {:student_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "subscribe_class_students/1" do
    test "subscribes the calling process to the class-students and preregistration topics", %{
      subscribe_class_students: subscribe_class_students
    } do
      %Class{} = class = CourseFactory.insert(:class)

      assert subscribe_class_students.(class) == :ok

      # The class-students topic carries student lifecycle broadcasts.
      %Student{} = student = CourseFactory.build(:student, class_id: class.id, user: nil)
      :ok = PubSub.publish_students_imported(class, [student])

      assert_receive {:students_imported, ^class, [^student]}

      # The Accounts preregistration topic (keyed by the same id) also reaches
      # the process, since a linked account changes a student's displayed
      # identity.
      preregistered_user = AccountsFactory.build(:preregistered_user, group_id: class.id)

      event =
        PreregisteredUserLinkedToUserAccount.new(
          preregistered_user,
          AccountsFactory.build(:user_account)
        )

      reference = EventsFactory.build(:event_reference)

      :ok =
        Accounts.PubSub.publish_preregistered_user_updated(preregistered_user, event, reference)

      assert_receive {:preregistered_user_updated, ^event, ^reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_class_students/4" do
    test "refetches the class students on a student, import or preregistration message", %{
      refresh_class_students: refresh_class_students,
      list_students: list_students
    } do
      %Class{} = class = CourseFactory.insert(:class)
      %Student{} = alice = CourseFactory.insert(:student, class: class, name: "Alice", user: nil)
      auth = Factory.build(:authentication, root: true)

      # The current list is deliberately stale (empty) so a passing assertion
      # proves the message triggered a fresh DB read rather than echoing the
      # given list.
      expected = {:ok, list_students.(auth, class)}
      assert expected != {:ok, []}

      created = {:student_created, %Student{alice | class_id: class.id}}
      deleted = {:student_deleted, %Student{alice | class_id: class.id}}

      updated =
        {:student_updated, %{class: %{id: class.id}}, EventsFactory.build(:event_reference)}

      imported = {:students_imported, class, [alice]}

      preregistration =
        {:preregistered_user_updated,
         PreregisteredUserLinkedToUserAccount.new(
           AccountsFactory.build(:preregistered_user, group_id: class.id),
           AccountsFactory.build(:user_account)
         ), EventsFactory.build(:event_reference)}

      assert refresh_class_students.(auth, class, [], created) == expected
      assert refresh_class_students.(auth, class, [], deleted) == expected
      assert refresh_class_students.(auth, class, [], updated) == expected
      assert refresh_class_students.(auth, class, [], imported) == expected
      assert refresh_class_students.(auth, class, [], preregistration) == expected

      assert_no_stored_events!()
    end

    test "ignores a student message for another class", %{
      refresh_class_students: refresh_class_students
    } do
      %Class{} = class = CourseFactory.insert(:class)
      %Class{} = other = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: true)

      other_student = CourseFactory.build(:student, class_id: other.id, user: nil)

      assert refresh_class_students.(auth, class, [], {:student_created, other_student}) ==
               :ignore

      assert refresh_class_students.(
               auth,
               class,
               [],
               {:student_updated, %{class: %{id: other.id}},
                EventsFactory.build(:event_reference)}
             ) == :ignore

      assert_no_stored_events!()
    end

    test "ignores a message it does not handle", %{
      refresh_class_students: refresh_class_students
    } do
      %Class{} = class = CourseFactory.insert(:class)
      auth = Factory.build(:authentication, root: true)

      assert refresh_class_students.(auth, class, [], :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "subscribe_student_detail/1" do
    test "subscribes the calling process to the student, class and preregistration topics", %{
      subscribe_student_detail: subscribe_student_detail
    } do
      %Class{} = class = CourseFactory.insert(:class)
      %Student{} = student = CourseFactory.insert(:student, class: class, user: nil)

      assert subscribe_student_detail.(student) == :ok

      # Student topic.
      student_updated = %Student{student | name: "Renamed", version: student.version + 1}
      student_event = StudentUpdated.new(student_updated)
      student_reference = EventsFactory.build(:event_reference, version: student_updated.version)
      :ok = PubSub.publish_student_updated(student_updated, student_event, student_reference)
      assert_receive {:student_updated, ^student_event, ^student_reference}

      # Class topic.
      class_updated = %Class{class | name: "Renamed", version: class.version + 1}
      class_event = ClassUpdated.new(class_updated)
      class_reference = EventsFactory.build(:event_reference, version: class_updated.version)
      :ok = PubSub.publish_class_updated(class_updated, class_event, class_reference)
      assert_receive {:class_updated, ^class_event, ^class_reference}

      # Accounts preregistration topic (keyed by the student id).
      preregistered_user =
        AccountsFactory.build(:preregistered_user, id: student.id, group_id: class.id)

      linkage_event =
        PreregisteredUserLinkedToUserAccount.new(
          preregistered_user,
          AccountsFactory.build(:user_account)
        )

      linkage_reference = EventsFactory.build(:event_reference)

      :ok =
        Accounts.PubSub.publish_preregistered_user_updated(
          preregistered_user,
          linkage_event,
          linkage_reference
        )

      assert_receive {:preregistered_user_updated, ^linkage_event, ^linkage_reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_student_detail/2" do
    test "reconciles the student from a student-updated message", %{
      refresh_student_detail: refresh_student_detail
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      updated = %Student{student | name: "Renamed", version: student.version + 1}
      event = StudentUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_student_detail.(student, {:student_updated, event, reference}) ==
               {:ok, Student.refresh!(student, event, reference)}

      assert_no_stored_events!()
    end

    test "reconciles the nested class from a class-updated message", %{
      refresh_student_detail: refresh_student_detail
    } do
      %Class{} = class = CourseFactory.build(:class)
      %Student{class: ^class} = student = CourseFactory.build(:student, class: class, user: nil)

      updated_class = %Class{class | name: "Renamed", version: class.version + 1}
      event = ClassUpdated.new(updated_class)
      reference = EventsFactory.build(:event_reference, version: updated_class.version)

      assert refresh_student_detail.(student, {:class_updated, event, reference}) ==
               {:ok, %Student{student | class: Class.refresh!(class, event, reference)}}

      assert_no_stored_events!()
    end

    test "ignores a class-updated message for another class", %{
      refresh_student_detail: refresh_student_detail
    } do
      %Class{} = class = CourseFactory.build(:class)
      %Class{} = other = CourseFactory.build(:class)
      %Student{} = student = CourseFactory.build(:student, class: class, user: nil)

      event = ClassUpdated.new(%Class{other | version: other.version + 1})
      reference = EventsFactory.build(:event_reference, version: other.version + 1)

      assert refresh_student_detail.(student, {:class_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end

    test "ignores messages it does not claim, including preregistration updates", %{
      refresh_student_detail: refresh_student_detail
    } do
      %Student{} = student = CourseFactory.build(:student, user: nil)

      preregistration =
        {:preregistered_user_updated,
         PreregisteredUserLinkedToUserAccount.new(
           AccountsFactory.build(:preregistered_user, id: student.id),
           AccountsFactory.build(:user_account)
         ), EventsFactory.build(:event_reference)}

      assert refresh_student_detail.(student, preregistration) == :ignore
      assert refresh_student_detail.(student, {:student_deleted, student}) == :ignore
      assert refresh_student_detail.(student, :unrelated) == :ignore

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
