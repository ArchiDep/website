defmodule ArchiDep.Course.StudentViewTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Support.CourseTestHelpers
  alias ArchiDep.Support.EventsFactory
  alias Ecto.UUID

  @now ~U[2024-01-01 08:00:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

  describe "refresh!/3" do
    test "merges a student-updated event one version ahead into the cached view" do
      {student, _user_account, _auth} = CourseTestHelpers.register_student()
      view = StudentView.from(student)

      # The event carries the next version and diverges from the persisted row
      # on every merged field, so the assertion can only pass if the in-memory
      # merge ran: the catch-all fallback would re-fetch and return the
      # persisted values instead.
      event = %StudentUpdated{
        id: view.id,
        name: "Renamed student",
        email: "renamed@example.ch",
        academic_class: "Renamed academic class",
        username: "renamedusername",
        domain: "renamed.archidep.ch",
        active: not view.active,
        servers_enabled: not view.servers_enabled,
        class: %{id: view.class_id, name: view.class.name}
      }

      assert StudentView.refresh!(
               view,
               event,
               EventsFactory.build(:event_reference,
                 version: view.version + 1,
                 occurred_at: @later
               )
             ) == %{
               view
               | name: "Renamed student",
                 email: "renamed@example.ch",
                 academic_class: "Renamed academic class",
                 username: "renamedusername",
                 domain: "renamed.archidep.ch",
                 active: event.active,
                 servers_enabled: event.servers_enabled,
                 version: view.version + 1,
                 updated_at: @later
             }
    end

    test "merges a student-configured event one version ahead into the cached view" do
      {student, _user_account, _auth} = CourseTestHelpers.register_student()
      view = StudentView.from(student)

      event = %StudentConfigured{
        id: view.id,
        name: view.name,
        email: view.email,
        username: "confirmedusername",
        class: %{id: view.class_id, name: view.class.name}
      }

      assert StudentView.refresh!(
               view,
               event,
               EventsFactory.build(:event_reference,
                 version: view.version + 1,
                 occurred_at: @later
               )
             ) == %{
               view
               | username: "confirmedusername",
                 username_confirmed: true,
                 version: view.version + 1,
                 updated_at: @later
             }
    end

    test "merges a preregistered-user-linked event into an as-yet unregistered view" do
      class = insert(:class, now: @now)
      student = insert(:student, class: class, user: nil, now: @now)
      {:ok, cached} = Student.fetch_student(student.id)
      view = StudentView.from(cached)
      assert view.user == nil

      # The persisted row is still unlinked, so a catch-all re-fetch would
      # return a view with no user; only the in-memory merge yields the linked
      # account.
      user_account_id = UUID.generate()

      event = %PreregisteredUserLinkedToUserAccount{
        preregistered_user_id: view.id,
        user_account: %{
          id: user_account_id,
          username: "linkeduser",
          active: true,
          version: 1
        }
      }

      assert StudentView.refresh!(
               view,
               event,
               EventsFactory.build(:event_reference,
                 version: view.version + 1,
                 occurred_at: @later
               )
             ) == %{
               view
               | user_id: user_account_id,
                 user: %User{
                   id: user_account_id,
                   username: "linkeduser",
                   active: true,
                   student_id: view.id,
                   version: 1,
                   created_at: @later,
                   updated_at: @later
                 },
                 version: view.version + 1,
                 updated_at: @later
             }
    end

    test "refreshes the nested class from a class event" do
      {student, _user_account, _auth} = CourseTestHelpers.register_student()
      view = StudentView.from(student)
      %ClassView{} = class = view.class

      {:ok, %Class{} = class_aggregate} = Class.fetch_class(class.id)

      event =
        ClassUpdated.new(%Class{class_aggregate | name: "Renamed", version: class.version + 1})

      reference =
        EventsFactory.build(:event_reference,
          version: class.version + 1,
          occurred_at: @later
        )

      assert StudentView.refresh!(view, event, reference) ==
               %{view | class: ClassView.refresh!(class, event, reference)}
    end

    test "ignores a student event at or below the cached version" do
      {student, _user_account, _auth} = CourseTestHelpers.register_student()
      view = StudentView.from(student)

      event = %StudentUpdated{
        id: view.id,
        name: "Ignored",
        email: view.email,
        academic_class: view.academic_class,
        username: view.username,
        domain: view.domain,
        active: view.active,
        servers_enabled: view.servers_enabled,
        class: %{id: view.class_id, name: view.class.name}
      }

      assert StudentView.refresh!(
               view,
               event,
               EventsFactory.build(:event_reference, version: view.version, occurred_at: @later)
             ) == view
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      {student, _user_account, _auth} = CourseTestHelpers.register_student()
      view = StudentView.from(student)

      {1, nil} =
        Repo.update_all(
          from(s in Student, where: s.id == ^view.id),
          set: [name: "Persisted rename", version: view.version + 2, updated_at: @later]
        )

      {:ok, fresh} = Student.fetch_student(view.id)
      fresh_view = StudentView.from(fresh)
      refute fresh_view == view

      event = %StudentUpdated{
        id: view.id,
        name: "Ignored",
        email: view.email,
        academic_class: view.academic_class,
        username: view.username,
        domain: view.domain,
        active: view.active,
        servers_enabled: view.servers_enabled,
        class: %{id: view.class_id, name: view.class.name}
      }

      assert StudentView.refresh!(
               view,
               event,
               EventsFactory.build(:event_reference,
                 version: view.version + 2,
                 occurred_at: @later
               )
             ) == fresh_view
    end
  end
end
