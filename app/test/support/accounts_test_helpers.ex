defmodule ArchiDep.Support.AccountsTestHelpers do
  @moduledoc """
  Helpers shared across the accounts context, in three flavours:

    * **Multi-entity orchestration** — `register_active_student/2` persists the
      multi-step dance of an active class, an active student in it, and a
      non-root user account linked to that student in **both** directions (the
      account's `preregistered_user_id` and the student's `user_id`). A student
      account can only log in or be validated while that whole chain is active,
      so the session use cases need it set up correctly. A *single* insert is
      never wrapped here — those stay visible at the call site (see below).

    * **Attribute builders** — `root_account_attrs/2` and `session_attrs/3`
      return the well-known factory attributes repeated across those four files.
      They return *options*; the `Factory.insert` call stays visible at the call
      site (`AccountsFactory.insert(:user_account, root_account_attrs(now))`),
      so they cut repetition without hiding the insert, per the factory
      conventions in `docs/testing.md`.

    * **Shared assertions** — `assert_session_untouched/1` and
      `preregistered_user_data/1` live here to reduce duplication.
  """

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import ArchiDep.Support.DataCase, only: [not_loaded: 2]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory

  @doc """
  Persists an **active student account** at the given instant: an active class
  (with a date window bracketing `now`), an active student in it, and a non-root
  user account linked to that student in both directions. Extra attributes are
  passed through to the student factory. Returns `{user_account, student}`.
  """
  @spec register_active_student(DateTime.t(), Enumerable.t()) :: {UserAccount.t(), Student.t()}
  def register_active_student(now, student_attrs \\ []) do
    class = CourseFactory.insert(:class, active: true, now: now)

    student =
      CourseFactory.insert(
        :student,
        student_attrs
        |> Map.new()
        |> Enum.into(%{active: true, class: class, user: nil, now: now})
      )

    user_account =
      AccountsFactory.insert(:user_account,
        # A generated (non-nil) username, since the factory leaves it optional.
        username: :generate,
        root: false,
        active: true,
        switch_edu_id: nil,
        preregistered_user_id: student.id,
        now: now
      )

    {1, nil} =
      Repo.update_all(
        from(s in Student, where: s.id == ^student.id),
        set: [user_id: user_account.id]
      )

    {user_account, student}
  end

  @doc """
  Well-known attributes for an active root user account at the given instant.
  Tests generally only override `active` for the inactive-account paths; the
  stable core lives here:

      AccountsFactory.insert(:user_account, root_account_attrs(now))
      AccountsFactory.insert(:user_account, root_account_attrs(now, active: false))
  """
  @spec root_account_attrs(DateTime.t(), Keyword.t()) :: Keyword.t()
  def root_account_attrs(now, overrides \\ []),
    do: Keyword.merge([root: true, active: true, switch_edu_id: nil, now: now], overrides)

  @doc """
  Well-known attributes for a session of `account` at the given instant.
  Defaults to a recently created (still-valid) session that is not
  impersonating; tests that care about the age (an expired session, or the
  sort-order fixtures) or that impersonate override the relevant keys:

      AccountsFactory.insert(:user_session, session_attrs(account, now))
      AccountsFactory.insert(:user_session, session_attrs(account, now, created_at: DateTime.add(now, -31, :day)))
  """
  @spec session_attrs(UserAccount.t(), DateTime.t(), Keyword.t()) :: Keyword.t()
  def session_attrs(account, now, overrides \\ []),
    do:
      Keyword.merge(
        [
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(now, -1, :hour)
        ],
        overrides
      )

  @doc """
  Asserts that the persisted session row is byte-for-byte the one inserted (its
  associations unloaded), proving a rejected or no-op use case left it
  untouched. Returns the session so it can be chained in a `|>` pipeline.
  """
  @spec assert_session_untouched(UserSession.t()) :: UserSession.t()
  def assert_session_untouched(session) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }

    session
  end

  @doc """
  The expected event-payload representation of a session owner's preregistered
  user: `nil` for a root account, and the `{id, name, email}` snapshot for a
  student account. Shared by the session-deletion, logout, and impersonation
  event assertions.
  """
  @spec preregistered_user_data(Student.t() | nil) :: map() | nil
  def preregistered_user_data(nil), do: nil

  def preregistered_user_data(%Student{} = student),
    do: %{"id" => student.id, "name" => student.name, "email" => student.email}
end
