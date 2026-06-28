defmodule ArchiDepWeb.Helpers.AuthHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Helpers.AuthHelpers
  alias Ecto.UUID

  describe "logged_in?/1" do
    test "an anonymous principal is not logged in" do
      refute AuthHelpers.logged_in?(nil)
    end

    test "an authenticated principal is logged in" do
      assert AuthHelpers.logged_in?(Factory.build(:authentication))
    end
  end

  describe "root?/1" do
    test "an anonymous principal is not root" do
      refute AuthHelpers.root?(nil)
    end

    test "a root principal is root" do
      assert AuthHelpers.root?(Factory.build(:authentication, root: true))
    end

    test "a non-root principal is not root" do
      refute AuthHelpers.root?(Factory.build(:authentication, root: false))
    end
  end

  describe "same_user?/2" do
    test "an anonymous principal is never the same user" do
      refute AuthHelpers.same_user?(nil, ServersFactory.build(:server_owner))
    end

    test "a principal is the same user as the owner sharing its id" do
      owner = ServersFactory.build(:server_owner)
      auth = Factory.build(:authentication, principal_id: owner.id)

      assert AuthHelpers.same_user?(auth, owner)
    end

    test "a principal is not the same user as an owner with a different id" do
      auth = Factory.build(:authentication)
      owner = ServersFactory.build(:server_owner)

      refute AuthHelpers.same_user?(auth, owner)
    end
  end

  describe "can_impersonate?/2" do
    test "an anonymous principal cannot impersonate" do
      refute AuthHelpers.can_impersonate?(nil, AccountsFactory.build(:user_account))
    end

    test "a root principal not already impersonating can impersonate another account" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert AuthHelpers.can_impersonate?(auth, AccountsFactory.build(:user_account))
    end

    test "a non-root principal cannot impersonate" do
      auth = Factory.build(:authentication, root: false, impersonated_id: nil)

      refute AuthHelpers.can_impersonate?(auth, AccountsFactory.build(:user_account))
    end

    test "a root principal already impersonating cannot impersonate again" do
      auth = Factory.build(:authentication, root: true, impersonated_id: UUID.generate())

      refute AuthHelpers.can_impersonate?(auth, AccountsFactory.build(:user_account))
    end

    test "a root principal cannot impersonate itself" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      refute AuthHelpers.can_impersonate?(
               auth,
               AccountsFactory.build(:user_account, id: auth.principal_id)
             )
    end
  end

  describe "impersonating?/1" do
    test "an anonymous principal is not impersonating" do
      refute AuthHelpers.impersonating?(nil)
    end

    test "a principal with no impersonated account is not impersonating" do
      refute AuthHelpers.impersonating?(Factory.build(:authentication, impersonated_id: nil))
    end

    test "a principal with an impersonated account is impersonating" do
      assert AuthHelpers.impersonating?(
               Factory.build(:authentication, impersonated_id: UUID.generate())
             )
    end
  end

  # username/1 delegates to ArchiDep.Authentication.username/1, which is covered
  # by that module's own tests.
end
