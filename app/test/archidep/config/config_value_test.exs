defmodule ArchiDep.Config.ConfigValueTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Config.ConfigError
  alias ArchiDep.Config.ConfigValue

  describe "new/1" do
    test "creates a value with only its description set" do
      assert ConfigValue.new("Some value") == %ConfigValue{description: "Some value"}
    end
  end

  describe "format/2" do
    test "adds a format description to the value" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.format(value, "It must be a positive integer.") == %ConfigValue{
               description: "Some value",
               format_description: "It must be a positive integer."
             }
    end
  end

  describe "env_var/4" do
    test "reads the raw value from the environment with the default parser" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.env_var(value, %{"SOME_VALUE" => "raw"}, "SOME_VALUE") == %ConfigValue{
               description: "Some value",
               value: "raw",
               original_value: "raw",
               source: {:env_var, "SOME_VALUE"},
               sources: [{:env_var, "SOME_VALUE"}]
             }
    end

    test "parses the value read from the environment with a custom parser" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.env_var(value, %{"SOME_VALUE" => "42"}, "SOME_VALUE", fn "42" ->
               {:ok, 42}
             end) == %ConfigValue{
               description: "Some value",
               value: 42,
               original_value: "42",
               source: {:env_var, "SOME_VALUE"},
               sources: [{:env_var, "SOME_VALUE"}]
             }
    end

    test "records the source but leaves the value unset when the variable is absent" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.env_var(value, %{}, "SOME_VALUE") == %ConfigValue{
               description: "Some value",
               value: nil,
               original_value: nil,
               source: {:env_var, "SOME_VALUE"},
               sources: [{:env_var, "SOME_VALUE"}]
             }
    end

    test "raises when the custom parser rejects the environment value" do
      value = ConfigValue.new("Some value")

      assert_raise ConfigError,
                   "Some value \"nope\" is invalid.\n" <>
                     "This value was set in environment variable $SOME_VALUE.",
                   fn ->
                     ConfigValue.env_var(
                       value,
                       %{"SOME_VALUE" => "nope"},
                       "SOME_VALUE",
                       fn _value ->
                         :error
                       end
                     )
                   end
    end
  end

  describe "default_to/3" do
    test "reads the value from a single configuration key" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.default_to(value, [some_value: "configured"], :some_value) ==
               %ConfigValue{
                 description: "Some value",
                 value: "configured",
                 original_value: "configured",
                 source: {:default_config, [:some_value]},
                 sources: [{:default_config, [:some_value]}]
               }
    end

    test "reads the value from a nested configuration key path" do
      value = ConfigValue.new("Root users")

      assert ConfigValue.default_to(
               value,
               [root_users: [switch_edu_id: ["a@archidep.ch"]]],
               [:root_users, :switch_edu_id]
             ) == %ConfigValue{
               description: "Root users",
               value: ["a@archidep.ch"],
               original_value: ["a@archidep.ch"],
               source: {:default_config, [:root_users, :switch_edu_id]},
               sources: [{:default_config, [:root_users, :switch_edu_id]}]
             }
    end

    test "leaves an already-set value untouched" do
      value =
        ConfigValue.env_var(ConfigValue.new("Some value"), %{"SOME_VALUE" => "raw"}, "SOME_VALUE")

      assert ConfigValue.default_to(value, [some_value: "configured"], :some_value) == value
    end
  end

  describe "validate/2" do
    test "skips validation when the value is unset" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.validate(value, fn _value -> false end) == value
    end

    test "returns the value unchanged when the validator accepts it" do
      value =
        ConfigValue.env_var(ConfigValue.new("Some value"), %{"SOME_VALUE" => "5"}, "SOME_VALUE")

      assert ConfigValue.validate(value, fn _value -> true end) == value
    end

    test "raises when the validator rejects the value" do
      value =
        "Some value"
        |> ConfigValue.new()
        |> ConfigValue.format("It must be big.")
        |> ConfigValue.default_to([some_value: 5], :some_value)

      assert_raise ConfigError,
                   "Some value 5 is invalid.\n" <>
                     "It must be big.\n" <>
                     "This value was set in one of the \"config/*.exs\" files.",
                   fn -> ConfigValue.validate(value, fn _value -> false end) end
    end
  end

  describe "validate_result/2" do
    test "skips validation when the value is unset" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.validate_result(value, fn _value -> {:error, "nope"} end) == value
    end

    test "returns the value unchanged when the validator accepts it" do
      value =
        ConfigValue.env_var(ConfigValue.new("Some value"), %{"SOME_VALUE" => "5"}, "SOME_VALUE")

      assert ConfigValue.validate_result(value, fn "5" -> {:ok, "5"} end) == value
    end

    test "raises with the reason when the validator rejects the value" do
      value =
        "Some value"
        |> ConfigValue.new()
        |> ConfigValue.format("It must be big.")
        |> ConfigValue.default_to([some_value: 5], :some_value)

      assert_raise ConfigError,
                   "Some value 5 is invalid: it is too small\n" <>
                     "It must be big.\n" <>
                     "This value was set in one of the \"config/*.exs\" files.",
                   fn ->
                     ConfigValue.validate_result(value, fn 5 -> {:error, "it is too small"} end)
                   end
    end
  end

  describe "required_value/1" do
    test "returns the value when it is set" do
      value =
        ConfigValue.env_var(ConfigValue.new("Some value"), %{"SOME_VALUE" => "raw"}, "SOME_VALUE")

      assert ConfigValue.required_value(value) == "raw"
    end

    test "raises when the value is unset, listing every source in order" do
      value =
        "Some value"
        |> ConfigValue.new()
        |> ConfigValue.env_var(%{}, "SOME_VALUE")
        |> ConfigValue.default_to([], :some_value)

      assert_raise ConfigError,
                   "Some value is required but was not provided.\n\n" <>
                     "Set it with environment variable $SOME_VALUE.\n" <>
                     "Or set it with one of the \"config/*.exs\" files.",
                   fn -> ConfigValue.required_value(value) end
    end

    test "raises when the value is an empty list, including the format description" do
      value =
        "Some value"
        |> ConfigValue.new()
        |> ConfigValue.format("It must not be empty.")
        |> ConfigValue.default_to([some_value: []], :some_value)

      assert_raise ConfigError,
                   "Some value is required but was not provided.\n" <>
                     "It must not be empty.\n\n" <>
                     "Set it with one of the \"config/*.exs\" files.",
                   fn -> ConfigValue.required_value(value) end
    end
  end

  describe "optional_value/1" do
    test "returns the value when it is set" do
      value =
        ConfigValue.env_var(ConfigValue.new("Some value"), %{"SOME_VALUE" => "raw"}, "SOME_VALUE")

      assert ConfigValue.optional_value(value) == "raw"
    end

    test "returns nil when the value is unset" do
      value = ConfigValue.new("Some value")

      assert ConfigValue.optional_value(value) == nil
    end
  end
end
