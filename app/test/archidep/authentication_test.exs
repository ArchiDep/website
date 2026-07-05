defmodule ArchiDep.AuthenticationTest do
  use ExUnit.Case, async: true

  import ArchiDep.Authentication, only: [is_authentication: 1]
  import ArchiDep.Support.Factory
  alias ArchiDep.Authentication

  describe "session_id/1" do
    test "returns the session id of the authentication" do
      session_id = Ecto.UUID.generate()
      auth = build(:authentication, session_id: session_id)

      assert Authentication.session_id(auth) == session_id
    end
  end

  describe "is_authentication/1 guard" do
    test "is true for an authentication struct" do
      assert classify(build(:authentication)) == :authentication
    end

    test "is false for any other value" do
      assert classify(%{}) == :other
      assert classify("not an authentication") == :other
      assert classify(nil) == :other
    end
  end

  defp classify(value) when is_authentication(value), do: :authentication
  defp classify(_value), do: :other
end
