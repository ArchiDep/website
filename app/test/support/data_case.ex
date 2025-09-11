defmodule ArchiDep.Support.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the application's
  data layer.

  You may define functions here to be used as helpers in your tests.

  Finally, if the test case interacts with the database, we enable the SQL
  sandbox, so changes done to the database are reverted at the end of every
  test. If you are using PostgreSQL, you can even run database tests
  asynchronously by setting `use ArchiDep.DataCase, async: true`, although this
  option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.DataCase
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Ecto.Schema.Metadata

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Support.DataCase
      alias ArchiDep.Events.Store.EventReference
      alias ArchiDep.Events.Store.StoredEvent
      alias ArchiDep.Repo
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)
    :ok
  end

  @spec loaded(module(), String.t()) :: Metadata.t()
  def loaded(schema, source), do: %Metadata{state: :loaded, schema: schema, source: source}

  @spec not_loaded(atom(), module()) :: NotLoaded.t()
  def not_loaded(field, owner),
    do: %NotLoaded{__field__: field, __owner__: owner, __cardinality__: :one}

  @spec assert_no_stored_events!() :: :ok
  def assert_no_stored_events! do
    assert Repo.all(StoredEvent) == []
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  @spec setup_sandbox(map()) :: :ok
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(ArchiDep.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)
  """
  @spec errors_on(Changeset.t()) :: %{optional(atom()) => [String.t()]}
  def errors_on(changeset),
    do:
      Changeset.traverse_errors(changeset, fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _whole_match, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
end
