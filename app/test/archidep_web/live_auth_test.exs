defmodule ArchiDepWeb.LiveAuthTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.StudentView
  alias ArchiDepWeb.ClientSessionData

  @path "/profile"

  # `LiveAuth.on_mount` runs through a real LiveView mount; the profile page is
  # the lightest authenticated page. Its mount-time context reads are stubbed as
  # ambient noise — the behaviour under test is the `"authenticated"` push_event
  # carrying the client session data. The anonymous-redirect branch of the hook
  # is covered suite-wide by `assert_live_anonymous_user_redirected_to_login`.

  test "push the authenticated session data for a root user", context do
    %{conn: conn, auth: auth, user_account: user_account} = register_and_log_in_root(context)

    stub(Accounts.ContextMock, :user_account, fn ^auth -> user_account end)
    stub(Accounts.ContextMock, :fetch_active_sessions, fn ^auth -> [] end)

    {:ok, view, _html} = live(conn, @path)

    expected = ClientSessionData.new(auth, nil)
    assert_push_event(view, "authenticated", ^expected)
  end

  test "push the authenticated session data for a student", context do
    %{conn: conn, auth: auth, user_account: user_account, student: student} =
      register_and_log_in_student(context)

    student_view = StudentView.from(student)

    stub(Accounts.ContextMock, :user_account, fn ^auth -> user_account end)
    stub(Accounts.ContextMock, :fetch_active_sessions, fn ^auth -> [] end)
    stub(Course.ContextMock, :fetch_authenticated_student, fn ^auth -> {:ok, student_view} end)
    stub(Course.ContextMock, :subscribe_student, fn ^student_view -> :ok end)

    {:ok, view, _html} = live(conn, @path)

    expected = ClientSessionData.new(auth, student_view)
    assert_push_event(view, "authenticated", ^expected)
  end
end
