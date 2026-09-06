defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionsLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Events.CourseSessionCreated
  alias ArchiDep.Course.UseCases.ReadCourseSessions
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionForm
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid
  alias ArchiDepWeb.Admin.CourseSessions.NewCourseSessionDialogLive
  alias Ecto.Changeset

  @path "/admin/course-sessions"
  @new_form_id "new-course-session-form"

  # The instant the page is opened at, and the day the form of a new session
  # fills in for itself from it.
  @now ~U[2026-09-18 07:30:00.000000Z]
  @today "2026-09-18"

  # A number the compiled course does not use, so a session recording it is one
  # whose chapter was renumbered or dropped since — which is routine, the
  # material being written as the course runs.
  @orphan 99_999

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    test "renders the page over a static (disconnected) request", %{conn: conn, auth: auth} do
      cli = session(date: ~D[2026-09-18], title: "CLI", done: [100])

      expect_page_calls(auth, mounts: 1, course_sessions: [cli])

      html = conn |> get(@path) |> html_response(200)

      assert_html_title(html, "Course progress · Admin · ArchiDep")

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{"2026-09-18", "CLI", nil, "100", "-", "-", ["Edit", "Delete"]}],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{cli.id}",
                 "delete-course-session-dialog-#{cli.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{cli.id}" => []
               }
             }
    end
  end

  describe "the sessions list" do
    setup :register_and_log_in_root

    test "renders every session the context answers with, in the order given", %{
      conn: conn,
      auth: auth
    } do
      cli = session(date: ~D[2026-09-18], title: "CLI", done: [100, 101], due: [102], next: [103])
      ssh = session(date: ~D[2026-09-25], title: "SSH")

      expect_page_calls(auth, course_sessions: [cli, ssh])

      {:ok, _view, html} = live(conn, @path)

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "CLI", nil, "100, 101", "102", "103", ["Edit", "Delete"]},
                 {"2026-09-25", "SSH", nil, "-", "-", "-", ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{cli.id}",
                 "edit-course-session-dialog-#{ssh.id}",
                 "delete-course-session-dialog-#{cli.id}",
                 "delete-course-session-dialog-#{ssh.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{cli.id}" => [],
                 "edit-course-session-form-#{ssh.id}" => []
               }
             }
    end

    test "renders a placeholder when nothing has been recorded", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      {:ok, _view, html} = live(conn, @path)

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "badges a session naming a chapter the course no longer has", %{conn: conn, auth: auth} do
      renumbered = session(date: ~D[2026-09-18], title: "CLI", done: [100], due: [@orphan])

      expect_page_calls(auth, course_sessions: [renumbered])

      {:ok, _view, html} = live(conn, @path)

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "CLI", "#{@orphan} no longer in the course", "100", "#{@orphan}",
                  "-", ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{renumbered.id}",
                 "delete-course-session-dialog-#{renumbered.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{renumbered.id}" => []
               }
             }
    end
  end

  describe "the grid of the form" do
    setup :register_and_log_in_root

    test "offers a grid row per section and chapter of the course in the form of a new session, none of them ticked",
         %{
           conn: conn,
           auth: auth
         } do
      expect_page_calls(auth, course_sessions: [])

      {:ok, _view, html} = live(conn, @path)

      assert grid(html, @new_form_id) == expected_grid(%{})

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "ticks what a recorded session holds in the grid of its form, orphans included", %{
      conn: conn,
      auth: auth
    } do
      [first_chapter, second_chapter] = Enum.take(chapter_numbers(), 2)

      recorded =
        session(
          date: ~D[2026-09-18],
          title: "CLI",
          done: [first_chapter, @orphan],
          due: [second_chapter],
          next: [first_chapter]
        )

      expect_page_calls(auth, course_sessions: [recorded])

      {:ok, _view, html} = live(conn, @path)

      assert grid(html, "edit-course-session-form-#{recorded.id}") ==
               expected_grid(
                 %{
                   first_chapter => {true, false, true},
                   second_chapter => {false, true, false},
                   @orphan => {true, false, false}
                 },
                 [@orphan]
               )

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "CLI", "#{@orphan} no longer in the course",
                  "#{first_chapter}, #{@orphan}", "#{second_chapter}", "#{first_chapter}",
                  ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{recorded.id}",
                 "delete-course-session-dialog-#{recorded.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{recorded.id}" => []
               }
             }
    end

    test "leaves what a recorded session marked done out of the grid of a new session, its own form still offering it",
         %{conn: conn, auth: auth} do
      [chapter | _rest] = chapter_numbers()

      recorded = session(date: ~D[2026-09-18], title: "CLI", done: [chapter])

      expect_page_calls(auth, course_sessions: [recorded])

      {:ok, _view, html} = live(conn, @path)

      assert grid(html, @new_form_id) ==
               Enum.reject(expected_grid(%{}), fn {num, _done, _due, _next} -> num == chapter end)

      assert grid(html, "edit-course-session-form-#{recorded.id}") ==
               expected_grid(%{chapter => {true, false, false}})

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "CLI", nil, "#{chapter}", "-", "-", ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{recorded.id}",
                 "delete-course-session-dialog-#{recorded.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{recorded.id}" => []
               }
             }
    end

    test "says a new session has nothing left to cover once the course is done", %{
      conn: conn,
      auth: auth
    } do
      done = CourseSessionGrid.course_numbers()

      recorded = session(date: ~D[2026-09-18], title: "Exam", done: done)

      expect_page_calls(auth, course_sessions: [recorded])

      {:ok, _view, html} = live(conn, @path)

      assert grid(html, @new_form_id) ==
               [{:nothing_left, "Every section and chapter of the course is done"}]

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "Exam", nil, Enum.join(done, ", "), "-", "-", ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{recorded.id}",
                 "delete-course-session-dialog-#{recorded.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{recorded.id}" => []
               }
             }
    end
  end

  describe "the day a new session is recorded on" do
    setup :register_and_log_in_root

    setup do
      stub(Clock.Mock, :now, fn -> @now end)
      :ok
    end

    test "is filled into the form of a new session", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      {:ok, _view, html} = live(conn, @path)

      assert form_fields(html, @new_form_id) == %{date: @today, title: ""}

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "is filled in again by a dialog that is closed on a session left unrecorded", %{
      conn: conn,
      auth: auth
    } do
      [chapter | _rest] = chapter_numbers()

      expect_page_calls(auth, course_sessions: [])

      expect(Course.ContextMock, :validate_course_session, fn _auth, _data ->
        Changeset.change(%CourseSessionForm{})
      end)

      {:ok, view, _html} = live(conn, @path)

      typed =
        view
        |> form("##{@new_form_id}",
          course_session: form_params("2026-09-25", "SSH", %{done: [chapter]})
        )
        |> render_change()

      assert form_fields(typed, @new_form_id) == %{date: "2026-09-25", title: "SSH"}
      assert grid(typed, @new_form_id) == expected_grid(%{chapter => {true, false, false}})

      closed =
        view |> element("##{NewCourseSessionDialogLive.id()} .modal-backdrop") |> render_click()

      assert form_fields(closed, @new_form_id) == %{date: @today, title: ""}
      assert grid(closed, @new_form_id) == expected_grid(%{})

      assert page(closed) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end
  end

  describe "recording a session" do
    setup :register_and_log_in_root

    test "records a session with what its form ticked", %{conn: conn, auth: auth} do
      [chapter | _rest] = chapter_numbers()

      expect_page_calls(auth, course_sessions: [])

      recorded = session(date: ~D[2026-09-18], title: "CLI", done: [chapter])
      test = self()

      expect(Course.ContextMock, :create_course_session, fn ^auth, data ->
        send(test, {:created, data})
        {:ok, recorded}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("##{@new_form_id}",
        course_session:
          form_params("2026-09-18", "CLI", %{
            done: [chapter]
          })
      )
      |> render_submit()

      assert_received {:created, data}

      assert data == %{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [chapter],
               due: [],
               next: []
             }
    end
  end

  describe "correcting a session" do
    setup :register_and_log_in_root

    test "corrects a session, emptying a category whose last box was unticked", %{
      conn: conn,
      auth: auth
    } do
      [chapter | _rest] = chapter_numbers()

      recorded = session(date: ~D[2026-09-18], title: "CLI", done: [chapter], due: [chapter])

      expect_page_calls(auth, course_sessions: [recorded])

      test = self()

      expect(Course.ContextMock, :update_course_session, fn ^auth, id, data ->
        send(test, {:updated, id, data})
        {:ok, %{recorded | due: []}}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form(
        "#edit-course-session-form-#{recorded.id}",
        course_session: form_params("2026-09-18", "CLI", %{done: [chapter]})
      )
      |> render_submit()

      assert_received {:updated, id, data}
      assert id == recorded.id

      # The category that lost its last tick comes through empty rather than
      # unchanged, which is what the hidden companion input of every box buys.
      assert data == %{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [chapter],
               due: [],
               next: []
             }
    end
  end

  describe "validating a session" do
    setup :register_and_log_in_root

    test "shows what the context says is wrong with a new session", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      test = self()

      expect(Course.ContextMock, :validate_course_session, fn ^auth, data ->
        send(test, {:validated, data})

        %CourseSessionForm{}
        |> Changeset.change()
        |> Changeset.add_error(:title, "is already the name of a session")
      end)

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("##{@new_form_id}", course_session: form_params("2026-09-18", "CLI", %{}))
        |> render_change()

      assert_received {:validated, data}

      assert data == %{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [],
               due: [],
               next: []
             }

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => ["is already the name of a session"]}
             }
    end

    test "does not ask the context about a form it can already tell is incomplete", %{
      conn: conn,
      auth: auth
    } do
      expect_page_calls(auth, course_sessions: [])

      {:ok, view, _html} = live(conn, @path)

      # No expectation is set for `validate_course_session/2`, so the mock is
      # what asserts the context was not asked. Nothing is shown as wrong yet
      # either: the errors of a form that has not been through the context are
      # withheld until it is submitted.
      html =
        view
        |> form("##{@new_form_id}", course_session: form_params("", "", %{}))
        |> render_change()

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "shows what the context says is wrong with a correction", %{conn: conn, auth: auth} do
      recorded = session(date: ~D[2026-09-18], title: "CLI")

      expect_page_calls(auth, course_sessions: [recorded])

      expect(Course.ContextMock, :validate_existing_course_session, fn ^auth, _id, _data ->
        {:ok,
         %CourseSessionForm{}
         |> Changeset.change()
         |> Changeset.add_error(:date, "is the day of another session")}
      end)

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("#edit-course-session-form-#{recorded.id}",
          course_session: form_params("2026-09-18", "CLI", %{})
        )
        |> render_change()

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{"2026-09-18", "CLI", nil, "-", "-", "-", ["Edit", "Delete"]}],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{recorded.id}",
                 "delete-course-session-dialog-#{recorded.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{recorded.id}" => [
                   "is the day of another session"
                 ]
               }
             }
    end
  end

  describe "a write the context refuses" do
    setup :register_and_log_in_root

    test "leaves the errors of a refused new session on its form", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      expect(Course.ContextMock, :create_course_session, fn ^auth, _data ->
        {:error,
         %CourseSessionForm{}
         |> Changeset.change()
         |> Changeset.add_error(:title, "is already the name of a session")}
      end)

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("##{@new_form_id}", course_session: form_params("2026-09-18", "CLI", %{}))
        |> render_submit()

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => ["is already the name of a session"]}
             }
    end

    test "leaves the errors of a refused correction on its form", %{conn: conn, auth: auth} do
      recorded = session(date: ~D[2026-09-18], title: "CLI")

      expect_page_calls(auth, course_sessions: [recorded])

      expect(Course.ContextMock, :update_course_session, fn ^auth, _id, _data ->
        {:error,
         %CourseSessionForm{}
         |> Changeset.change()
         |> Changeset.add_error(:title, "is already the name of a session")}
      end)

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("#edit-course-session-form-#{recorded.id}",
          course_session: form_params("2026-09-18", "CLI", %{})
        )
        |> render_submit()

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{"2026-09-18", "CLI", nil, "-", "-", "-", ["Edit", "Delete"]}],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{recorded.id}",
                 "delete-course-session-dialog-#{recorded.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{recorded.id}" => [
                   "is already the name of a session"
                 ]
               }
             }
    end
  end

  describe "deleting a session" do
    setup :register_and_log_in_root

    test "deletes the session whose dialog was confirmed", %{
      conn: conn,
      auth: auth
    } do
      recorded = session(date: ~D[2026-09-18], title: "CLI")
      test = self()

      expect_page_calls(auth, course_sessions: [recorded])

      expect(Course.ContextMock, :delete_course_session, fn ^auth, id ->
        send(test, {:deleted, id})
        :ok
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> element(~s(#delete-course-session-dialog-#{recorded.id} button.btn-error))
      |> render_click()

      assert_received {:deleted, id}
      assert id == recorded.id
    end
  end

  describe "the outcome of the last build" do
    setup :register_and_log_in_root

    test "says nothing about the last build until the site has been rendered", %{
      conn: conn,
      auth: auth
    } do
      expect_page_calls(auth, course_sessions: [])

      {:ok, _view, html} = live(conn, @path)

      assert page(html) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "says the site was rendered again", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      {:ok, view, _html} = live(conn, @path)

      send(view.pid, {:course_site_built, {:ok, report()}})

      assert page(render(view)) == %{
               last_build: {:success, "The site was rendered again."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end

    test "says the site could not be rendered", %{conn: conn, auth: auth} do
      expect_page_calls(auth, course_sessions: [])

      {:ok, view, _html} = live(conn, @path)

      send(
        view.pid,
        {:course_site_built,
         {:error, "The site could not be rendered", ["a document says nothing"]}}
      )

      assert page(render(view)) == %{
               last_build:
                 {:failure,
                  "The site could not be rendered (The site could not be rendered), so what is being served is unchanged. The reasons are in the application log."},
               sessions: [{:no_sessions, "No sessions recorded"}],
               dialogs: ["new-course-session-dialog"],
               errors: %{"new-course-session-form" => []}
             }
    end
  end

  describe "live list updates" do
    setup :register_and_log_in_root

    test "re-reads the list when a session is recorded elsewhere", %{conn: conn, auth: auth} do
      cli = session(date: ~D[2026-09-18], title: "CLI", done: [100])
      ssh = session(date: ~D[2026-09-25], title: "SSH", done: [101])

      expect_page_calls(auth, course_sessions: [cli])

      {:ok, view, _html} = live(conn, @path)

      # The refresher re-reads rather than reconciling, so the second answer is
      # what the page shows.
      expect(Course.ContextMock, :list_course_sessions, fn ^auth -> [cli, ssh] end)

      :ok =
        Course.PubSub.publish_course_session_created(
          CourseSessionCreated.new(ssh),
          EventsFactory.build(:event_reference)
        )

      assert page(render(view)) == %{
               last_build: {:none, "The site has not been rendered since this page was opened."},
               sessions: [
                 {"2026-09-18", "CLI", nil, "100", "-", "-", ["Edit", "Delete"]},
                 {"2026-09-25", "SSH", nil, "101", "-", "-", ["Edit", "Delete"]}
               ],
               dialogs: [
                 "new-course-session-dialog",
                 "edit-course-session-dialog-#{cli.id}",
                 "edit-course-session-dialog-#{ssh.id}",
                 "delete-course-session-dialog-#{cli.id}",
                 "delete-course-session-dialog-#{ssh.id}"
               ],
               errors: %{
                 "new-course-session-form" => [],
                 "edit-course-session-form-#{cli.id}" => [],
                 "edit-course-session-form-#{ssh.id}" => []
               }
             }
    end
  end

  # Every category is pinned, empty unless the test says otherwise: what the
  # page shows of a session is the whole of what it recorded.
  defp session(overrides),
    do:
      CourseFactory.build(
        :course_session,
        Keyword.merge([done: [], due: [], next: []], overrides)
      )

  defp expect_page_calls(auth, opts) do
    mounts = Keyword.get(opts, :mounts, 2)
    course_sessions = Keyword.fetch!(opts, :course_sessions)

    expect(Course.ContextMock, :list_course_sessions, mounts, fn ^auth -> course_sessions end)

    # The page keeps the list current through the Course boundary; route those
    # calls to the real read-model plumbing so a real broadcast still drives the
    # re-render.
    stub(
      Course.ContextMock,
      :subscribe_course_sessions,
      &ReadCourseSessions.subscribe_course_sessions/0
    )

    stub(
      Course.ContextMock,
      :refresh_course_sessions,
      &ReadCourseSessions.refresh_course_sessions/3
    )

    :ok
  end

  # The whole of what the page shows, as one value: what it says of the last
  # build, the sessions it lists, the dialogs it holds ready for them, and what
  # each of its forms says is wrong. What a form holds is what is left out —
  # its grid is a row per section and chapter of the course — and `grid/2` and
  # `form_fields/2` project it whole where a test is about it.
  defp page(html),
    do: %{
      last_build: last_build(html),
      sessions: sessions_table(html),
      dialogs: dialog_ids(html),
      errors: form_errors(html)
    }

  defp dialog_ids(html),
    do: html |> find_html_elements("dialog") |> Enum.map(&html_element_attribute(&1, "id"))

  # Every form of the page and what it says is wrong, so that an error shown on
  # the wrong form fails as loudly as one that is missing. The backdrop of a
  # dialog is a form too, and carries no id.
  defp form_errors(html),
    do:
      html
      |> find_html_elements("form[id]")
      |> Map.new(fn form ->
        {html_element_attribute(form, "id"),
         form |> find_html_elements("p.text-error") |> Enum.map(&html_element_text/1)}
      end)

  # Projects the body of the sessions table: one entry per recorded session —
  # the day, the name, the badge naming what the course no longer has (or its
  # absence), what each of the three categories shows, and what can be done to
  # the session — or the placeholder row the table shows when nothing has been
  # recorded.
  defp sessions_table(html),
    do: html |> find_html_elements(~s(#course-sessions tbody tr)) |> Enum.map(&project_row/1)

  defp project_row(row) do
    case html_element_attribute(row, "id") do
      nil -> {:no_sessions, html_element_text(row)}
      _id -> project_session_row(row)
    end
  end

  defp project_session_row(row) do
    [date_td, title_td, done_td, due_td, next_td, actions_td] = find_html_elements(row, "td")
    [title] = find_html_elements(title_td, ".course-session-title")

    orphans =
      case find_html_elements(title_td, ".course-session-orphans") do
        [] -> nil
        [badge] -> html_element_text(badge)
      end

    {html_element_text(date_td), html_element_text(title), orphans, html_element_text(done_td),
     html_element_text(due_td), html_element_text(next_td), row_actions(actions_td)}
  end

  # What a row offers to do with the session, by the label each button carries
  # for a screen reader, its icon saying nothing.
  defp row_actions(cell),
    do: cell |> find_html_elements("button") |> Enum.map(&html_element_text/1)

  # The values a form of a session holds, its grid apart: the day and the name
  # somebody has typed into it, or the ones it starts from.
  defp form_fields(html, form_id),
    do:
      Map.new([:date, :title], fn field ->
        [input] = find_html_elements(html, ~s(##{form_id} input[name="course_session[#{field}]"]))
        {field, html_element_attribute(input, "value")}
      end)

  # Projects the whole grid of a form: one entry per row it offers, in order,
  # saying which of the three boxes are ticked — or the placeholder row of a
  # grid that has nothing left to offer.
  defp grid(html, form_id),
    do:
      html
      |> find_html_elements(~s(##{form_id}-grid tbody tr))
      |> Enum.map(&project_grid_row(&1, form_id))

  defp project_grid_row(row, form_id) do
    case html_element_attribute(row, "id") do
      nil ->
        {:nothing_left, html_element_text(row)}

      id ->
        num = String.replace_prefix(id, "#{form_id}-row-", "")

        {String.to_integer(num), ticked?(row, :done, num), ticked?(row, :due, num),
         ticked?(row, :next, num)}
    end
  end

  defp ticked?(row, category, num) do
    [box] =
      find_html_elements(
        row,
        ~s(input[type="checkbox"][name="course_session[#{category}][#{num}]"])
      )

    html_element_attribute(box, "checked") != nil
  end

  # The grid the course as it stands calls for, plus the orphan rows, with the
  # given numbers ticked. Built from the same compiled course the page reads so
  # that a renumbered chapter is not a hardcoded list to maintain; what the test
  # pins is which boxes are ticked, and that every row is offered.
  defp expected_grid(ticked, orphans \\ []),
    do:
      Enum.map(CourseSessionGrid.course_numbers() ++ orphans, fn num ->
        {done, due, next} = Map.get(ticked, num, {false, false, false})
        {num, done, due, next}
      end)

  defp chapter_numbers,
    do: Enum.reject(CourseSessionGrid.course_numbers(), &(rem(&1, 100) == 0))

  # Every box of the grid, so that a submitted form says as much about what was
  # unticked as about what was ticked.
  defp form_params(date, title, ticked) do
    boxes =
      Map.new([:done, :due, :next], fn category ->
        numbers = Map.get(ticked, category, [])

        {Atom.to_string(category),
         Map.new(CourseSessionGrid.course_numbers(), fn num ->
           {Integer.to_string(num), to_string(num in numbers)}
         end)}
      end)

    Map.merge(%{"date" => date, "title" => title}, boxes)
  end

  defp last_build(html) do
    [region] = find_html_elements(html, "#last-build div")

    kind =
      cond do
        find_html_elements(html, "#last-build .alert-success") != [] -> :success
        find_html_elements(html, "#last-build .alert-error") != [] -> :failure
        true -> :none
      end

    {kind, html_element_text(region)}
  end

  defp report,
    do: %Report{
      output_dir: "/var/lib/archidep/site/build",
      pages: 64,
      chapters: 50,
      files: 77,
      page_assets: 362,
      assets: 143
    }
end
