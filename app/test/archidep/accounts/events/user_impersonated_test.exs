defmodule ArchiDep.Accounts.Events.UserImpersonatedTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Accounts.Events.UserImpersonated
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Support.AccountsFactory

  describe "new/2" do
    test "builds the event when both accounts have a Switch edu-ID and preregistration" do
      impersonator_switch_edu_id = AccountsFactory.build(:switch_edu_id)
      impersonator_preregistration = AccountsFactory.build(:preregistered_user)
      impersonated_switch_edu_id = AccountsFactory.build(:switch_edu_id)
      impersonated_preregistration = AccountsFactory.build(:preregistered_user)

      impersonated =
        AccountsFactory.build(:user_account,
          switch_edu_id: impersonated_switch_edu_id,
          preregistered_user: impersonated_preregistration
        )

      session =
        AccountsFactory.build(:user_session,
          user_account:
            AccountsFactory.build(:user_account,
              switch_edu_id: impersonator_switch_edu_id,
              preregistered_user: impersonator_preregistration
            )
        )

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      %UserAccount{id: impersonated_id, username: impersonated_username, root: impersonated_root} =
        impersonated

      assert UserImpersonated.new(session, impersonated) == %UserImpersonated{
               session_id: session_id,
               user_account: %{
                 id: user_account_id,
                 username: username,
                 root: root,
                 switch_edu_id: %{
                   id: impersonator_switch_edu_id.id,
                   first_name: impersonator_switch_edu_id.first_name,
                   last_name: impersonator_switch_edu_id.last_name
                 },
                 preregistered_user: %{
                   id: impersonator_preregistration.id,
                   name: impersonator_preregistration.name,
                   email: impersonator_preregistration.email
                 }
               },
               impersonated_user_account: %{
                 id: impersonated_id,
                 username: impersonated_username,
                 root: impersonated_root,
                 switch_edu_id: %{
                   id: impersonated_switch_edu_id.id,
                   first_name: impersonated_switch_edu_id.first_name,
                   last_name: impersonated_switch_edu_id.last_name
                 },
                 preregistered_user: %{
                   id: impersonated_preregistration.id,
                   name: impersonated_preregistration.name,
                   email: impersonated_preregistration.email
                 }
               }
             }
    end

    test "builds the event when neither account has a Switch edu-ID nor a preregistration" do
      impersonated =
        AccountsFactory.build(:user_account, switch_edu_id: nil, preregistered_user: nil)

      session =
        AccountsFactory.build(:user_session,
          user_account:
            AccountsFactory.build(:user_account, switch_edu_id: nil, preregistered_user: nil)
        )

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      %UserAccount{id: impersonated_id, username: impersonated_username, root: impersonated_root} =
        impersonated

      assert UserImpersonated.new(session, impersonated) == %UserImpersonated{
               session_id: session_id,
               user_account: %{
                 id: user_account_id,
                 username: username,
                 root: root,
                 switch_edu_id: nil,
                 preregistered_user: nil
               },
               impersonated_user_account: %{
                 id: impersonated_id,
                 username: impersonated_username,
                 root: impersonated_root,
                 switch_edu_id: nil,
                 preregistered_user: nil
               }
             }
    end
  end
end
