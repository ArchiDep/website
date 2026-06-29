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

  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Clock.SystemClock
  alias ArchiDep.Events.Store.EventReference
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
      alias Ecto.Changeset
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)

    # By default the injected clock returns the real system time, so tests that
    # do not care about time behave as if `DateTime.utc_now/0` were called
    # directly. Tests that assert exact timestamps override this with their own
    # `stub`/`expect` pinning a fixed instant (see `docs/testing.md`).
    Hammox.stub(ArchiDep.Clock.Mock, :now, &SystemClock.now/0)

    # Scope global PubSub topics to this test with a unique suffix so concurrent
    # async tests never observe each other's broadcasts on shared topics (see
    # `docs/testing.md`).
    topic_suffix = ":test-#{System.unique_integer([:positive])}"
    Hammox.stub(ArchiDep.PubSub.Scope.Mock, :suffix, fn -> topic_suffix end)

    :ok
  end

  @spec loaded(module(), String.t()) :: Metadata.t()
  def loaded(schema, source), do: %Metadata{state: :loaded, schema: schema, source: source}

  @spec not_loaded(atom(), module()) :: NotLoaded.t()
  def not_loaded(field, owner),
    do: %NotLoaded{__field__: field, __owner__: owner, __cardinality__: :one}

  # Stored-event payloads serialise dates to ISO-8601 strings (via Jason), so
  # tests that reconstruct an expected event payload, or rebuild a row from one,
  # convert between `Date` structs and those strings with these helpers.

  @spec date_to_iso8601(Date.t() | nil) :: String.t() | nil
  def date_to_iso8601(nil), do: nil
  def date_to_iso8601(%Date{} = date), do: Date.to_iso8601(date)

  @spec date_from_iso8601(String.t() | nil) :: Date.t() | nil
  def date_from_iso8601(nil), do: nil
  def date_from_iso8601(iso) when is_binary(iso), do: Date.from_iso8601!(iso)

  @spec assert_no_stored_events!() :: :ok
  def assert_no_stored_events! do
    assert Repo.all(StoredEvent) == []
    :ok
  end

  @spec assert_no_stored_events!(list(StoredEvent.t(map) | EventReference.t())) :: :ok
  def assert_no_stored_events!(except) do
    ids = Enum.map(except, & &1.id)
    assert Repo.all(from(e in StoredEvent, where: e.id not in ^ids)) == []
    :ok
  end

  @spec fetch_new_stored_events() :: list(StoredEvent.t(map))
  @spec fetch_new_stored_events(list(StoredEvent.t(map) | EventReference.t())) ::
          list(StoredEvent.t(map))
  def fetch_new_stored_events(except \\ []) do
    ids_to_exclude = Enum.map(except, & &1.id)

    Repo.all(
      from e in StoredEvent,
        where: e.id not in ^ids_to_exclude,
        order_by: [asc: e.occurred_at]
    )
  end

  @doc """
  Captures each given schema's current row count, for `assert_row_count_diff/2`
  or `assert_no_row_count_diff/1`. Snapshot before invoking the use case, then
  assert how the counts changed afterwards.
  """
  @spec count_rows([module()]) :: %{module() => non_neg_integer()}
  def count_rows(schemas),
    do: Map.new(schemas, fn schema -> {schema, Repo.aggregate(schema, :count)} end)

  @doc """
  Asserts how the row counts captured by `count_rows/1` changed: each watched
  table must have changed by exactly the delta given for it, and every watched
  table _not_ listed in `expected_diff` must be unchanged. This states what a
  use case did to the database as a difference rather than asserting absolute
  counts.

      previous_counts = count_rows([Class, ExpectedServerProperties, StoredEvent])
      assert delete_class.(auth, class.id) == :ok
      assert_row_count_diff(previous_counts, %{Class => -1, ExpectedServerProperties => -1, StoredEvent => 1})
  """
  @spec assert_row_count_diff(%{module() => non_neg_integer()}, %{module() => integer()}) :: :ok
  def assert_row_count_diff(previous_counts, expected_diff) do
    after_counts = count_rows(Map.keys(previous_counts))

    actual_diff =
      Map.new(previous_counts, fn {schema, before} -> {schema, after_counts[schema] - before} end)

    expected_diff_with_zeros =
      Map.new(previous_counts, fn {schema, _before} ->
        {schema, Map.get(expected_diff, schema, 0)}
      end)

    assert actual_diff == expected_diff_with_zeros

    :ok
  end

  @doc """
  Asserts none of the row counts captured by `count_rows/1` changed — every
  watched table has exactly as many rows as before. Use it to prove a rejected
  or side-effect-free call (an error path, or a `validate_*` function) wrote
  nothing.
  """
  @spec assert_no_row_count_diff(%{module() => non_neg_integer()}) :: :ok
  def assert_no_row_count_diff(previous_counts), do: assert_row_count_diff(previous_counts, %{})

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
