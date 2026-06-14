defmodule ArchiDep.Accounts.Schemas.PreregisteredUserTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias Ecto.Changeset

  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "active?/2" do
    test "a preregistered user is active when it and its group are both active" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      assert PreregisteredUser.active?(preregistered_user, @now)
    end

    test "an inactive preregistered user is never active" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: false, group: group)

      refute PreregisteredUser.active?(preregistered_user, @now)
    end

    test "an active preregistered user in an inactive group is not active" do
      group = build(:user_group, active: false, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      refute PreregisteredUser.active?(preregistered_user, @now)
    end
  end

  describe "link_to_user_account/3" do
    test "linking an unlinked preregistered user sets the account, bumps the version and touches it" do
      account = build(:user_account)

      preregistered_user =
        build(:preregistered_user, user_account: nil, user_account_id: nil, version: 2)

      changeset = PreregisteredUser.link_to_user_account(preregistered_user, account, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %{
               preregistered_user
               | user_account: account,
                 user_account_id: account.id,
                 updated_at: @now
             }

      # `optimistic_lock(:version)` filters the update on the current version
      # and bumps it only at update time, so the bump is absent from the applied
      # struct above; the filter is the schema-level observable, and the
      # conflicting-update path itself is covered by the login-link use case.
      assert changeset.filters == %{version: 2}
    end

    test "linking to the account it is already linked to is a no-op changeset" do
      account = build(:user_account)

      preregistered_user =
        build(:preregistered_user, user_account: account, user_account_id: account.id, version: 2)

      changeset = PreregisteredUser.link_to_user_account(preregistered_user, account, @now)

      assert changeset.valid?
      assert changeset.changes == %{}
    end
  end
end
