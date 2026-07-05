defmodule ArchiDep.PubSub.Scope.GlobalScopeTest do
  use ExUnit.Case, async: true

  alias ArchiDep.PubSub.Scope.GlobalScope

  describe "suffix/0" do
    test "applies no suffix so global topics keep their shared names" do
      assert GlobalScope.suffix() == ""
    end
  end
end
