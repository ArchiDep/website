defmodule ArchiDep.Accounts.Events.SessionDeletedTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Accounts.Events.SessionDeleted
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Support.AccountsFactory

  describe "new/1" do
    test "builds the event for a session whose account has a Switch edu-ID and preregistration" do
      switch_edu_id = AccountsFactory.build(:switch_edu_id)
      preregistered_user = AccountsFactory.build(:preregistered_user)

      session =
        AccountsFactory.build(:user_session,
          user_account:
            AccountsFactory.build(:user_account,
              switch_edu_id: switch_edu_id,
              preregistered_user: preregistered_user
            )
        )

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username}
      } =
        session

      %SwitchEduId{id: switch_edu_id_id, first_name: first_name, last_name: last_name} =
        switch_edu_id

      %PreregisteredUser{id: preregistered_user_id, name: name, email: email} = preregistered_user

      assert SessionDeleted.new(session) == %SessionDeleted{
               user_account: %{id: user_account_id, username: username},
               switch_edu_id: %{
                 id: switch_edu_id_id,
                 first_name: first_name,
                 last_name: last_name
               },
               session_id: session_id,
               preregistered_user: %{id: preregistered_user_id, name: name, email: email}
             }
    end

    test "builds the event for a session whose account has neither a Switch edu-ID nor a preregistration" do
      session =
        AccountsFactory.build(:user_session,
          user_account:
            AccountsFactory.build(:user_account, switch_edu_id: nil, preregistered_user: nil)
        )

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username}
      } =
        session

      assert SessionDeleted.new(session) == %SessionDeleted{
               user_account: %{id: user_account_id, username: username},
               switch_edu_id: nil,
               session_id: session_id,
               preregistered_user: nil
             }
    end
  end
end
