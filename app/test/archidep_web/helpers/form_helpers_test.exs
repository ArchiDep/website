defmodule ArchiDepWeb.Helpers.FormHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDepWeb.Helpers.FormHelpers

  describe "tmp_boolify/2" do
    test "converts the value true at the key to the boolean true" do
      assert FormHelpers.tmp_boolify(%{"flag" => "true", "other" => "kept"}, "flag") ==
               %{"flag" => true, "other" => "kept"}
    end

    test "converts the value false at the key to the boolean false" do
      assert FormHelpers.tmp_boolify(%{"flag" => "false", "other" => "kept"}, "flag") ==
               %{"flag" => false, "other" => "kept"}
    end

    test "returns the params unchanged when the key is absent" do
      assert FormHelpers.tmp_boolify(%{"other" => "kept"}, "flag") == %{"other" => "kept"}
    end

    test "returns the params unchanged when the value is not a boolean string" do
      assert FormHelpers.tmp_boolify(%{"flag" => "maybe"}, "flag") == %{"flag" => "maybe"}
    end
  end
end
