defmodule ArchiDep.Accounts.Events.UserRegisteredWithLinkTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Accounts.Events.UserRegisteredWithLink
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Support.AccountsFactory

  describe "new/3" do
    test "builds the event with the preregistered user" do
      login_link = AccountsFactory.build(:login_link)
      preregistered_user = AccountsFactory.build(:preregistered_user)

      session =
        AccountsFactory.build(:user_session,
          client_ip_address: "203.0.113.5",
          client_user_agent: "Test UA",
          user_account: AccountsFactory.build(:user_account, root: false)
        )

      %LoginLink{id: login_link_id} = login_link

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      %PreregisteredUser{id: preregistered_user_id, name: name, email: email} = preregistered_user

      assert UserRegisteredWithLink.new(login_link, session, preregistered_user) ==
               %UserRegisteredWithLink{
                 login_link: %{id: login_link_id},
                 user_account: %{id: user_account_id, username: username, root: root},
                 session_id: session_id,
                 client_ip_address: "203.0.113.5",
                 client_user_agent: "Test UA",
                 preregistered_user: %{id: preregistered_user_id, name: name, email: email}
               }
    end

    test "builds the event without a preregistered user" do
      login_link = AccountsFactory.build(:login_link)

      session =
        AccountsFactory.build(:user_session,
          client_ip_address: "203.0.113.5",
          client_user_agent: "Test UA",
          user_account: AccountsFactory.build(:user_account, root: false)
        )

      %LoginLink{id: login_link_id} = login_link

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      assert UserRegisteredWithLink.new(login_link, session, nil) == %UserRegisteredWithLink{
               login_link: %{id: login_link_id},
               user_account: %{id: user_account_id, username: username, root: root},
               session_id: session_id,
               client_ip_address: "203.0.113.5",
               client_user_agent: "Test UA",
               preregistered_user: nil
             }
    end
  end
end
