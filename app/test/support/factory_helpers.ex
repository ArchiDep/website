defmodule ArchiDep.Support.FactoryHelpers do
  @moduledoc """
  Helper functions for generating test fixtures in factories.
  """

  alias Ecto.UUID

  @booleans [true, false]

  @spec optional((-> term())) :: term() | nil
  def optional(fun), do: if(bool(), do: fun.(), else: nil)

  @spec optionally((-> term())) :: (-> term() | nil)
  def optionally(fun), do: fn -> optional(fun) end

  # Pops the reference time used to generate entity timestamps and date windows.
  # Defaults to the current time; pass a `:now` attribute to pin it so that
  # generated timestamps are consistent with a fixed clock (see
  # `docs/testing.md`).
  @spec pop_now(map()) :: {DateTime.t(), map()}
  def pop_now(attrs), do: Map.pop_lazy(attrs, :now, &DateTime.utc_now/0)

  @spec pop_entity_version_and_timestamps(map()) ::
          {pos_integer(), DateTime.t(), DateTime.t(), map()}
  @spec pop_entity_version_and_timestamps(map(), DateTime.t()) ::
          {pos_integer(), DateTime.t(), DateTime.t(), map()}
  def pop_entity_version_and_timestamps(attrs!, now \\ DateTime.utc_now()) do
    {version, attrs!} = pop_entity_version(attrs!)
    {created_at, attrs!} = pop_entity_created_at(attrs!, now)
    {updated_at, attrs!} = pop_entity_updated_at(attrs!, created_at, version, now)
    {version, created_at, updated_at, attrs!}
  end

  @spec pop_entity_id(map()) :: {UUID.t(), map()}
  def pop_entity_id(attrs), do: Map.pop_lazy(attrs, :id, &entity_id/0)

  @spec pop_entity_version(map()) :: {pos_integer(), map()}
  def pop_entity_version(attrs), do: Map.pop_lazy(attrs, :version, &entity_version/0)

  @spec pop_entity_created_at(map()) :: {DateTime.t(), map()}
  @spec pop_entity_created_at(map(), DateTime.t()) :: {DateTime.t(), map()}
  def pop_entity_created_at(attrs, now \\ DateTime.utc_now()),
    do: Map.pop_lazy(attrs, :created_at, fn -> entity_created_at(now) end)

  @spec pop_entity_updated_at(map(), DateTime.t()) :: {DateTime.t(), map()}
  def pop_entity_updated_at(attrs, created_at),
    do: Map.pop_lazy(attrs, :updated_at, fn -> entity_updated_at(created_at) end)

  @spec pop_entity_updated_at(map(), DateTime.t(), pos_integer()) :: {DateTime.t(), map()}
  @spec pop_entity_updated_at(map(), DateTime.t(), pos_integer(), DateTime.t()) ::
          {DateTime.t(), map()}
  def pop_entity_updated_at(attrs, created_at, version, now \\ DateTime.utc_now()),
    do: Map.pop_lazy(attrs, :updated_at, fn -> entity_updated_at(created_at, version, now) end)

  @spec entity_id() :: UUID.t()
  def entity_id, do: UUID.generate()

  @spec entity_version() :: pos_integer()
  def entity_version, do: Faker.random_between(1, 10)

  @spec entity_created_at() :: DateTime.t()
  @spec entity_created_at(DateTime.t()) :: DateTime.t()
  def entity_created_at(now \\ DateTime.utc_now()),
    do: Faker.DateTime.between(DateTime.add(now, -1000 * 86_400, :second), now)

  @spec entity_updated_at(DateTime.t()) :: DateTime.t()
  def entity_updated_at(created_at), do: Faker.DateTime.between(created_at, DateTime.utc_now())

  @spec entity_updated_at(DateTime.t(), pos_integer()) :: DateTime.t()
  @spec entity_updated_at(DateTime.t(), pos_integer(), DateTime.t()) :: DateTime.t()
  def entity_updated_at(created_at, version, now \\ DateTime.utc_now())
  def entity_updated_at(created_at, 1, _now), do: created_at
  def entity_updated_at(created_at, _version, now), do: Faker.DateTime.between(created_at, now)

  @spec bool() :: boolean()
  def bool, do: Enum.random(@booleans)
end
