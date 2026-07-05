defmodule ArchiDep.SentryTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Sentry

  describe "before_send/1" do
    test "drops an event coming from the test environment" do
      assert Sentry.before_send(%{environment: "test", message: "boom"}) == nil
    end

    test "passes any other event through unchanged" do
      event = %{environment: "production", message: "boom", extra: %{foo: "bar"}}

      assert Sentry.before_send(event) == event
    end
  end
end
