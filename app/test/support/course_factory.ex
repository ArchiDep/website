defmodule ArchiDep.Support.CourseFactory do
  @moduledoc """
  Test fixtures for the course context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties

  @spec class_factory(map()) :: Class.t()
  def class_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {name, attrs!} =
      Map.pop_lazy(attrs!, :name, fn ->
        sequence(:class_name, &"Class #{&1}")
      end)

    {start_date, attrs!} =
      Map.pop_lazy(attrs!, :start_date, optionally(fn -> Faker.DateTime.backward(365) end))

    {end_date, attrs!} =
      Map.pop_lazy(attrs!, :end_date, optionally(fn -> Faker.DateTime.forward(365) end))

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)

    {expected_server_properties, attrs!} =
      Map.pop_lazy(attrs!, :expected_server_properties, fn ->
        build(:expected_server_properties)
      end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %Class{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      expected_server_properties: expected_server_properties,
      expected_server_properties_id: expected_server_properties.id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec expected_server_properties_factory(map()) :: ExpectedServerProperties.t()
  def expected_server_properties_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {hostname, attrs!} =
      Map.pop_lazy(attrs!, :hostname, optionally(&Faker.Internet.domain_name/0))

    {machine_id, attrs!} = Map.pop_lazy(attrs!, :machine_id, optionally(&Faker.String.base64/0))

    {cpus, attrs!} =
      Map.pop_lazy(attrs!, :cpus, optionally(fn -> Faker.random_between(1, 16) end))

    {cores, attrs!} =
      Map.pop_lazy(attrs!, :cores, optionally(fn -> Faker.random_between(1, 16) end))

    {vcpus, attrs!} =
      Map.pop_lazy(attrs!, :vcpus, optionally(fn -> Faker.random_between(1, 32) end))

    {memory, attrs!} =
      Map.pop_lazy(attrs!, :memory, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {swap, attrs!} =
      Map.pop_lazy(attrs!, :swap, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {system, attrs!} = Map.pop_lazy(attrs!, :system, optionally(&Faker.Company.buzzword/0))

    {architecture, attrs!} =
      Map.pop_lazy(attrs!, :architecture, optionally(&Faker.Company.buzzword/0))

    {os_family, attrs!} = Map.pop_lazy(attrs!, :os_family, optionally(&Faker.Company.buzzword/0))

    {distribution, attrs!} =
      Map.pop_lazy(attrs!, :distribution, optionally(&Faker.Company.buzzword/0))

    {distribution_release, attrs!} =
      Map.pop_lazy(attrs!, :distribution_release, &Faker.Company.buzzword/0)

    {distribution_version, attrs!} =
      Map.pop_lazy(attrs!, :distribution_version, &Faker.Company.buzzword/0)

    [] = Map.keys(attrs!)

    %ExpectedServerProperties{
      id: id,
      hostname: hostname,
      machine_id: machine_id,
      cpus: cpus,
      cores: cores,
      vcpus: vcpus,
      memory: memory,
      swap: swap,
      system: system,
      architecture: architecture,
      os_family: os_family,
      distribution: distribution,
      distribution_release: distribution_release,
      distribution_version: distribution_version
    }
  end
end
