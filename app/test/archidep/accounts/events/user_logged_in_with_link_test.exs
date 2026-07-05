defmodule ArchiDep.Accounts.Events.UserLoggedInWithLinkTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Accounts.Events.UserLoggedInWithLink
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.Factory

  describe "new/3" do
    test "builds the event with a preregistered link and a client IP address" do
      preregistered_user = AccountsFactory.build(:preregistered_user)
      login_link = AccountsFactory.build(:login_link, preregistered_user: preregistered_user)

      session =
        AccountsFactory.build(:user_session,
          user_account: AccountsFactory.build(:user_account, root: false)
        )

      client_metadata =
        Factory.build(:client_metadata, ip_address: {203, 0, 113, 5}, user_agent: "Test UA")

      %LoginLink{id: login_link_id} = login_link

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      %PreregisteredUser{id: preregistered_user_id, name: name, email: email} = preregistered_user

      assert UserLoggedInWithLink.new(login_link, session, client_metadata) ==
               %UserLoggedInWithLink{
                 login_link: %{id: login_link_id},
                 user_account: %{id: user_account_id, username: username, root: root},
                 session_id: session_id,
                 client_ip_address: "203.0.113.5",
                 client_user_agent: "Test UA",
                 preregistered_user: %{id: preregistered_user_id, name: name, email: email}
               }
    end

    test "builds the event without a preregistered link nor a client IP address" do
      login_link = AccountsFactory.build(:login_link, preregistered_user: nil)

      session =
        AccountsFactory.build(:user_session,
          user_account: AccountsFactory.build(:user_account, root: false)
        )

      client_metadata = Factory.build(:client_metadata, ip_address: nil, user_agent: nil)

      %LoginLink{id: login_link_id} = login_link

      %UserSession{
        id: session_id,
        user_account: %UserAccount{id: user_account_id, username: username, root: root}
      } = session

      assert UserLoggedInWithLink.new(login_link, session, client_metadata) ==
               %UserLoggedInWithLink{
                 login_link: %{id: login_link_id},
                 user_account: %{id: user_account_id, username: username, root: root},
                 session_id: session_id,
                 client_ip_address: nil,
                 client_user_agent: nil,
                 preregistered_user: nil
               }
    end
  end
end
