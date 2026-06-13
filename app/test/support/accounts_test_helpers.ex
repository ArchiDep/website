defmodule ArchiDep.Support.AccountsTestHelpers do
  @moduledoc """
  Helpers for setting up accounts-context fixtures that are awkward to build
  with a single factory call — in particular an **active student account**,
  which is the multi-step dance of an active class, an active student in it, and
  a non-root user account linked to that student in **both** directions (the
  account's `preregistered_user_id` and the student's `user_id`). A student
  account can only log in or be validated while that whole chain is active, so
  session use cases need it set up correctly.

  Single-row fixtures (a root account, a session) are not wrapped here — those
  stay as visible `Factory.insert(:thing, …)` calls at the test call site, per
  the factory conventions in `docs/testing.md`. This module is only for genuine
  multi-entity orchestration.
  """

  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Accounts.Schemas.UserAccount
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
end
