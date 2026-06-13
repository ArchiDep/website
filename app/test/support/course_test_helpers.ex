defmodule ArchiDep.Support.CourseTestHelpers do
  @moduledoc """
  Helpers for setting up course-context fixtures that are awkward to build with
  a single factory call — in particular the multi-step dance required to persist
  a student linked to a user account in **both** directions (the account's
  `student_id` and the student's `user_account_id`), which is what the
  self-service use cases (`configure_student`, `fetch_authenticated_student`)
  authorize against.
  """

  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Authentication
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # A fixed past instant for the persisted fixtures, so that a use case stamping
  # `updated_at` at the test's pinned clock visibly moves it forward.
  @fixture_now ~U[2023-09-15 09:42:17.000000Z]

  @doc """
  Persists a student linked to a non-root user account in both directions, and
  builds the matching self-service authentication. Extra attributes are passed
  through to the student factory. Returns `{student, user_account, auth}`, with
  the student read back the way the use cases read it.
  """
  @spec register_student(Enumerable.t()) :: {Student.t(), UserAccount.t(), Authentication.t()}
  def register_student(student_attrs \\ []) do
    student =
      CourseFactory.insert(
        :student,
        student_attrs |> Map.new() |> Enum.into(%{user: nil, user_id: nil, now: @fixture_now})
      )

    user_account =
      AccountsFactory.insert(:user_account,
        # A generated (non-nil) username: the course `User.t()` loaded into the
        # returned student requires one, and the factory leaves it optional.
        username: :generate,
        root: false,
        active: true,
        switch_edu_id: nil,
        preregistered_user_id: student.id,
        now: @fixture_now
      )

    {1, nil} =
      Repo.update_all(
        from(s in Student, where: s.id == ^student.id),
        set: [user_id: user_account.id]
      )

    {:ok, linked_student} = Student.fetch_student(student.id)
    auth = Factory.build(:authentication, principal_id: user_account.id, root: false)

    {linked_student, user_account, auth}
  end

  @doc """
  Persists a root account and an authentication for it (a use case may load the
  account before the policy's root short-circuit applies, so the row must
  exist). Returns `{auth, user_account}`.
  """
  @spec register_root() :: {Authentication.t(), UserAccount.t()}
  def register_root do
    user_account = AccountsFactory.insert(:user_account, root: true, active: true)
    auth = Factory.build(:authentication, principal_id: user_account.id, root: true)
    {auth, user_account}
  end
end
