defmodule ArchiDep.Support.CourseFactory do
  @moduledoc """
  Test fixtures for the course context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User

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

  @spec student_factory(map()) :: Student.t()
  def student_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {name, attrs!} =
      Map.pop_lazy(attrs!, :name, fn ->
        sequence(:student_name, &"Student #{&1}")
      end)

    {email, attrs!} = Map.pop_lazy(attrs!, :email, &Faker.Internet.email/0)

    {academic_class, attrs!} =
      Map.pop_lazy(
        attrs!,
        :academic_class,
        optionally(fn -> sequence(:student_academic_class, &"Academic class #{&1}") end)
      )

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn -> sequence(:student_username, &"student-#{&1}") end)

    {username_confirmed, attrs!} = Map.pop_lazy(attrs!, :username_confirmed, &bool/0)
    {domain, attrs!} = Map.pop_lazy(attrs!, :domain, &Faker.Internet.domain_name/0)

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)
    {class, attrs!} = Map.pop_lazy(attrs!, :class, fn -> build(:class) end)

    {class_id, attrs!} =
      Map.pop_lazy(attrs!, :class_id, fn ->
        case class do
          %Class{} -> class.id
          _not_loaded -> UUID.generate()
        end
      end)

    {user, attrs!} = Map.pop_lazy(attrs!, :user, optionally(fn -> build(:user) end))

    {user_id, attrs!} =
      Map.pop_lazy(attrs!, :user_id, fn ->
        case user do
          %User{} -> user.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %Student{
      id: id,
      name: name,
      email: email,
      academic_class: academic_class,
      username: username,
      username_confirmed: username_confirmed,
      domain: domain,
      active: active,
      servers_enabled: servers_enabled,
      class: class,
      class_id: class_id,
      user: user,
      user_id: user_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec user_factory(map()) :: User.t()
  def user_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn ->
        sequence(:user_username, &"user-account-#{&1}")
      end)

    {student, attrs!} =
      Map.pop_lazy(attrs!, :student, fn -> build(:student) end)

    {student_id, attrs!} =
      Map.pop_lazy(attrs!, :student_id, fn ->
        case student do
          %Student{} -> student.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %User{
      id: id,
      username: username,
      student: student,
      student_id: student_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
