defmodule ArchiDep.Accounts.Schemas.LoginLinkTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  import ArchiDep.Support.TokenTestHelpers
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias Ecto.Changeset

  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "new_token_for_preregistered_user_changeset/2" do
    test "builds an active link with a secure random token for the preregistered user" do
      preregistered_user = build(:preregistered_user)

      changeset =
        LoginLink.new_token_for_preregistered_user_changeset(preregistered_user, @now)

      assert errors_on(changeset) == %{}
      login_link = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(login_link.id)
      assert_secure_random_token(login_link.token)

      assert login_link == %LoginLink{
               id: login_link.id,
               token: login_link.token,
               active: true,
               used_at: nil,
               preregistered_user: preregistered_user,
               preregistered_user_id: preregistered_user.id,
               user_account: not_loaded(:user_account, LoginLink),
               user_account_id: nil,
               created_at: @now
             }
    end
  end

  describe "mark_as_used_changeset/2" do
    test "stamps used_at and takes the optimistic lock that flips the link inactive" do
      login_link = build(:login_link, active: true, used_at: nil)

      changeset = LoginLink.mark_as_used_changeset(login_link, @now)

      assert errors_on(changeset) == %{}
      assert Changeset.apply_changes(changeset) == %{login_link | used_at: @now}

      # `optimistic_lock(:active, fn true -> false end)` filters on the link
      # still being active and flips it to false only at update time, so the
      # flip is absent from the applied struct above; the filter on the current
      # value is the schema-level observable.
      assert changeset.filters == %{active: true}
    end
  end
end
