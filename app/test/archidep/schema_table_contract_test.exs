defmodule ArchiDep.SchemaTableContractTest do
  use ArchiDep.Support.DataCase, async: true

  # Several schemas are read views (or shared kernels) over a physical table
  # that another bounded context owns and writes (e.g.
  # `Servers.Schemas.ServerOwner` over the Accounts-owned `user_accounts`). Such
  # a mapping couples on the table layout, not a published contract, so a
  # migration in the owning context that renames or drops a mapped column would
  # break the dependent at runtime with no compile-time warning. This test
  # discovers every Ecto schema in the application and asserts each mapped
  # column still exists on its table; the guard therefore covers new schemas
  # automatically, with no registry to keep in sync.

  test "every column mapped by a schema exists on its physical table" do
    missing =
      for schema <- schemas(),
          missing = missing_columns(schema),
          missing != [],
          into: %{} do
        {schema, missing}
      end

    assert missing == %{}
  end

  defp schemas do
    {:ok, modules} = :application.get_key(:archidep, :modules)

    Enum.filter(modules, fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1) and
        module.__schema__(:source) != nil
    end)
  end

  defp missing_columns(schema) do
    mapped = MapSet.new(mapped_columns(schema))
    actual = MapSet.new(table_columns(schema.__schema__(:source)))
    mapped |> MapSet.difference(actual) |> Enum.sort()
  end

  # Resolve every schema field to its physical column, honouring `source:`
  # overrides (e.g. the `group_member` association's `student_id` column).
  # `__schema__(:fields)` already excludes loaded associations, embeds and
  # virtual fields, which have no column.
  defp mapped_columns(schema) do
    Enum.map(schema.__schema__(:fields), fn field ->
      Atom.to_string(schema.__schema__(:field_source, field))
    end)
  end

  defp table_columns(table) do
    %{rows: rows} =
      Repo.query!(
        "SELECT column_name FROM information_schema.columns WHERE table_name = $1",
        [table]
      )

    List.flatten(rows)
  end
end
