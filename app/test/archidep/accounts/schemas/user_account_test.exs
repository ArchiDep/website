defmodule ArchiDep.Accounts.Schemas.UserAccountTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Support.CourseFactory
  alias Ecto.Changeset

  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "active?/2" do
    test "an active root account with no preregistration is active" do
      account = build(:user_account, root: true, active: true, preregistered_user: nil)

      assert UserAccount.active?(account, @now)
    end

    test "an inactive root account is not active" do
      account = build(:user_account, root: false, active: false, preregistered_user: nil)
      root = build(:user_account, root: true, active: false, preregistered_user: nil)

      refute UserAccount.active?(account, @now)
      refute UserAccount.active?(root, @now)
    end

    test "a non-root account is active when it and its preregistration are active" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      account =
        build(:user_account, root: false, active: true, preregistered_user: preregistered_user)

      assert UserAccount.active?(account, @now)
    end

    test "a non-root account with an inactive preregistration is not active" do
      group = build(:user_group, active: false, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      account =
        build(:user_account, root: false, active: true, preregistered_user: preregistered_user)

      refute UserAccount.active?(account, @now)
    end

    test "an inactive non-root account is not active even with an active preregistration" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      account =
        build(:user_account, root: false, active: false, preregistered_user: preregistered_user)

      refute UserAccount.active?(account, @now)
    end

    test "a root account that carries a preregistration falls through to not active" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)
      preregistered_user = build(:preregistered_user, active: true, group: group)

      account =
        build(:user_account, root: true, active: true, preregistered_user: preregistered_user)

      refute UserAccount.active?(account, @now)
    end
  end

  describe "new_root_switch_edu_id_account/3" do
    test "builds an active root account, trimming the matched identifier into the username" do
      switch_edu_id = build(:switch_edu_id)

      changeset = UserAccount.new_root_switch_edu_id_account(switch_edu_id, "  alice  ", @now)

      assert errors_on(changeset) == %{}
      account = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(account.id)

      assert account == %UserAccount{
               id: account.id,
               username: "alice",
               root: true,
               active: true,
               switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
               switch_edu_id_id: switch_edu_id.id,
               preregistered_user: not_loaded(:preregistered_user, UserAccount),
               preregistered_user_id: nil,
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end

    test "a blank matched identifier becomes a nil username" do
      switch_edu_id = build(:switch_edu_id)

      changeset = UserAccount.new_root_switch_edu_id_account(switch_edu_id, "   ", @now)

      assert errors_on(changeset) == %{}
      account = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(account.id)

      assert account == %UserAccount{
               id: account.id,
               username: nil,
               root: true,
               active: true,
               switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
               switch_edu_id_id: switch_edu_id.id,
               preregistered_user: not_loaded(:preregistered_user, UserAccount),
               preregistered_user_id: nil,
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end
  end

  describe "new_preregistered_switch_edu_id_account/3" do
    test "builds an active non-root account linked to both the Switch edu-ID and the preregistration" do
      switch_edu_id = build(:switch_edu_id)
      preregistered_user = build(:preregistered_user)

      changeset =
        UserAccount.new_preregistered_switch_edu_id_account(
          switch_edu_id,
          preregistered_user,
          @now
        )

      assert errors_on(changeset) == %{}
      account = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(account.id)

      assert account == %UserAccount{
               id: account.id,
               username: nil,
               root: false,
               active: true,
               switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
               switch_edu_id_id: switch_edu_id.id,
               preregistered_user: preregistered_user,
               preregistered_user_id: preregistered_user.id,
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end
  end

  describe "new_preregistered_account/2" do
    test "builds an active non-root account linked only to the preregistration" do
      preregistered_user = build(:preregistered_user)

      changeset = UserAccount.new_preregistered_account(preregistered_user, @now)

      assert errors_on(changeset) == %{}
      account = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(account.id)

      assert account == %UserAccount{
               id: account.id,
               username: nil,
               root: false,
               active: true,
               switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
               switch_edu_id_id: nil,
               preregistered_user: preregistered_user,
               preregistered_user_id: preregistered_user.id,
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end
  end

  describe "link_to_switch_edu_id/3" do
    test "links an unlinked account to a Switch edu-ID, touching it and taking the optimistic lock" do
      switch_edu_id = build(:switch_edu_id)

      account =
        build(:user_account, switch_edu_id: nil, switch_edu_id_id: nil, version: 4)

      changeset = UserAccount.link_to_switch_edu_id(account, switch_edu_id, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %{
               account
               | switch_edu_id_id: switch_edu_id.id,
                 updated_at: @now
             }

      # The version bump from the optimistic lock lands only at update time, so
      # it is absent from the applied struct above; the filter is the
      # schema-level observable.
      assert changeset.filters == %{version: 4}
    end

    test "rejects a Switch edu-ID already linked to another account" do
      switch_edu_id = insert(:switch_edu_id)

      insert(:user_account,
        root: true,
        switch_edu_id: switch_edu_id,
        switch_edu_id_id: switch_edu_id.id
      )

      account = build(:user_account, switch_edu_id: nil, switch_edu_id_id: nil)

      changeset = UserAccount.link_to_switch_edu_id(account, switch_edu_id, @now)

      assert errors_on(changeset) == %{switch_edu_id_id: ["has already been taken"]}
    end
  end

  describe "relink_to_preregistered_user/3" do
    test "relinks an account to a preregistered user, touching it and taking the optimistic lock" do
      preregistered_user = build(:preregistered_user)

      account =
        build(:user_account,
          preregistered_user: nil,
          preregistered_user_id: nil,
          switch_edu_id: nil,
          version: 4
        )

      changeset = UserAccount.relink_to_preregistered_user(account, preregistered_user, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %{
               account
               | preregistered_user_id: preregistered_user.id,
                 updated_at: @now
             }

      assert changeset.filters == %{version: 4}
    end

    test "rejects a preregistered user already linked to another account" do
      # `PreregisteredUser` is the accounts-side projection of a course student
      # row, so a persisted student gives a preregistered user a real id to link.
      student = CourseFactory.insert(:student, now: @now)
      preregistered_user = build(:preregistered_user, id: student.id)
      insert(:user_account, root: false, preregistered_user_id: student.id, switch_edu_id: nil)

      account =
        build(:user_account,
          preregistered_user: nil,
          preregistered_user_id: nil,
          switch_edu_id: nil
        )

      changeset = UserAccount.relink_to_preregistered_user(account, preregistered_user, @now)

      assert errors_on(changeset) == %{preregistered_user_id: ["has already been taken"]}
    end
  end
end
