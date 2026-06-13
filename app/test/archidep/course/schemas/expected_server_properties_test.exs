defmodule ArchiDep.Course.Schemas.ExpectedServerPropertiesTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias Ecto.Changeset

  describe "update/2" do
    test "blank data is valid (every field is optional)" do
      assert errors_on(changeset(%{})) == %{}
    end

    # Every string field has the same length rule (only the limit differs), so
    # the limits are listed once and the comprehension generates one test each.
    for {field, max} <- [
          hostname: 255,
          machine_id: 255,
          system: 50,
          architecture: 20,
          os_family: 50,
          distribution: 50,
          distribution_release: 50,
          distribution_version: 20
        ] do
      test "#{field} cannot be longer than #{max} characters" do
        field = unquote(field)
        max = unquote(max)

        assert errors_on(changeset(%{field => String.duplicate("a", max + 1)})) ==
                 %{field => ["should be at most #{max} character(s)"]}
      end
    end

    # Same numeric rule for every integer field (only the upper bound differs).
    # The `{number}` placeholder is resolved by the translation layer at render
    # time, so the raw changeset error keeps it literal.
    for {field, max} <- [
          cpus: 32_767,
          cores: 32_767,
          vcpus: 32_767,
          memory: 2_147_483_647,
          swap: 2_147_483_647
        ] do
      test "#{field} must be at least 1" do
        assert errors_on(changeset(%{unquote(field) => 0})) ==
                 %{unquote(field) => ["must be between 1 and {number}"]}
      end

      test "#{field} cannot exceed #{max}" do
        assert errors_on(changeset(%{unquote(field) => unquote(max) + 1})) ==
                 %{unquote(field) => ["must be between 1 and {number}"]}
      end

      test "#{field} accepts its boundary values" do
        assert errors_on(changeset(%{unquote(field) => 1})) == %{}
        assert errors_on(changeset(%{unquote(field) => unquote(max)})) == %{}
      end
    end

    test "string fields are trimmed" do
      assert Changeset.get_change(changeset(%{hostname: "  host  "}), :hostname) == "host"
    end

    test "blank string fields are stored as nil" do
      properties = build(:expected_server_properties, hostname: "set")

      changeset = ExpectedServerProperties.update(properties, %{hostname: "   "})

      assert Changeset.get_field(changeset, :hostname) == nil
    end

    test "validation errors accumulate across fields" do
      assert errors_on(
               changeset(%{
                 hostname: String.duplicate("a", 256),
                 cpus: 0,
                 memory: 2_147_483_648
               })
             ) == %{
               hostname: ["should be at most 255 character(s)"],
               cpus: ["must be between 1 and {number}"],
               memory: ["must be between 1 and {number}"]
             }
    end
  end

  defp changeset(data), do: ExpectedServerProperties.update(%ExpectedServerProperties{}, data)
end
