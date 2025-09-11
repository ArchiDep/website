defmodule ArchiDep.Support.EventsFactory do
  @moduledoc """
  Test fixtures for the events context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Events.Store.StoredEvent

  @spec context() :: :accounts | :course | :events | :servers
  def context, do: Faker.Util.pick([:accounts, :course, :events, :servers])

  @spec stored_event_factory(map()) :: SwitchEduId.t()
  def stored_event_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {stream, attrs!} =
      Map.pop_lazy(attrs!, :stream, &__MODULE__.context/0)

    {version, attrs!} = Map.pop_lazy(attrs!, :version, fn -> Faker.random_between(1, 100) end)

    {type, attrs!} =
      Map.pop_lazy(attrs!, :type, fn ->
        "archidep/#{context()}/#{Faker.Lorem.words() |> Enum.join("-")}"
      end)

    {data, attrs!} =
      Map.pop_lazy(attrs!, :data, fn ->
        Map.put(%{}, Faker.Lorem.word(), Faker.Lorem.sentence())
      end)

    {meta, attrs!} =
      Map.pop_lazy(attrs!, :meta, fn ->
        Map.put(%{}, Faker.Lorem.word(), Faker.Lorem.sentence())
      end)

    {initiator, attrs!} =
      Map.pop(attrs!, :initiator, fn ->
        if bool() do
          "accounts/user-accounts/#{UUID.generate()}"
        else
          "servers/servers/#{UUID.generate()}"
        end
      end)

    {causation_id, attrs!} =
      Map.pop_lazy(attrs!, :causation_id, &UUID.generate/0)

    {correlation_id, attrs!} =
      Map.pop_lazy(attrs!, :correlation_id, &UUID.generate/0)

    {occurred_at, attrs!} =
      Map.pop_lazy(attrs!, :occurred_at, fn -> Faker.DateTime.backward(30) end)

    {entity, attrs!} = Map.pop(attrs!, :entity, nil)

    [] = Map.keys(attrs!)

    %StoredEvent{
      id: id,
      stream: stream,
      version: version,
      type: type,
      data: data,
      meta: meta,
      initiator: initiator,
      causation_id: causation_id,
      correlation_id: correlation_id,
      occurred_at: occurred_at,
      entity: entity
    }
  end
end
