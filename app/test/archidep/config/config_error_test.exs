defmodule ArchiDep.Config.ConfigErrorTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Config.ConfigError

  describe "exception/1" do
    test "builds the exception from a message string" do
      assert ConfigError.exception("something is wrong") == %ConfigError{
               message: "something is wrong"
             }
    end
  end
end
