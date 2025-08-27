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

  @spec pop_entity_version_and_timestamps(map()) ::
          {pos_integer(), DateTime.t(), DateTime.t(), map()}
  def pop_entity_version_and_timestamps(attrs!) do
    {version, attrs!} = pop_entity_version(attrs!)
    {created_at, attrs!} = pop_entity_created_at(attrs!)
    {updated_at, attrs!} = pop_entity_updated_at(attrs!, created_at, version)
    {version, created_at, updated_at, attrs!}
  end

  @spec pop_entity_id(map()) :: {UUID.t(), map()}
  def pop_entity_id(attrs), do: Map.pop_lazy(attrs, :id, &entity_id/0)

  @spec pop_entity_version(map()) :: {pos_integer(), map()}
  def pop_entity_version(attrs), do: Map.pop_lazy(attrs, :version, &entity_version/0)

  @spec pop_entity_created_at(map()) :: {DateTime.t(), map()}
  def pop_entity_created_at(attrs), do: Map.pop_lazy(attrs, :created_at, &entity_created_at/0)

  @spec pop_entity_updated_at(map(), DateTime.t()) :: {DateTime.t(), map()}
  def pop_entity_updated_at(attrs, created_at),
    do: Map.pop_lazy(attrs, :updated_at, fn -> entity_updated_at(created_at) end)

  @spec pop_entity_updated_at(map(), DateTime.t(), pos_integer()) :: {DateTime.t(), map()}
  def pop_entity_updated_at(attrs, created_at, version),
    do: Map.pop_lazy(attrs, :updated_at, fn -> entity_updated_at(created_at, version) end)

  @spec entity_id() :: UUID.t()
  def entity_id, do: UUID.generate()

  @spec entity_version() :: pos_integer()
  def entity_version, do: Faker.random_between(1, 10)

  @spec entity_created_at() :: DateTime.t()
  def entity_created_at, do: Faker.DateTime.backward(1000)

  @spec entity_updated_at(DateTime.t()) :: DateTime.t()
  def entity_updated_at(created_at), do: Faker.DateTime.between(created_at, DateTime.utc_now())

  @spec entity_updated_at(DateTime.t(), pos_integer()) :: DateTime.t()
  def entity_updated_at(created_at, 1), do: created_at

  def entity_updated_at(created_at, _version),
    do: Faker.DateTime.between(created_at, DateTime.utc_now())

  @spec bool() :: boolean()
  def bool, do: Enum.random(@booleans)
end
