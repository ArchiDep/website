defmodule ArchiDep.Support.CourseFactory do
  @moduledoc """
  Test fixtures for the course context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Course.Types
  alias ArchiDep.Support.SSHFactory

  @spec class_factory(map()) :: Class.t()
  def class_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {name, attrs!} =
      Map.pop_lazy(attrs!, :name, fn ->
        sequence(:class_name, &"Class #{&1}")
      end)

    {now, attrs!} = pop_now(attrs!)
    {start_date, end_date, attrs!} = pop_class_date_window(attrs!, now)

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)

    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)

    {teacher_ssh_public_keys, attrs!} =
      Map.pop(attrs!, :teacher_ssh_public_keys, [])

    {ssh_exercise_vm_md5_host_key_fingerprints, attrs!} =
      Map.pop_lazy(
        attrs!,
        :ssh_exercise_vm_md5_host_key_fingerprints,
        optionally(fn -> random_ssh_host_key_fingerprints(:md5) end)
      )

    {ssh_exercise_vm_sha256_host_key_fingerprints, attrs!} =
      Map.pop_lazy(
        attrs!,
        :ssh_exercise_vm_sha256_host_key_fingerprints,
        optionally(fn -> random_ssh_host_key_fingerprints(:sha256) end)
      )

    {expected_server_properties, attrs!} =
      Map.pop_lazy(attrs!, :expected_server_properties, fn ->
        build(:expected_server_properties)
      end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!, now)

    [] = Map.keys(attrs!)

    %Class{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      teacher_ssh_public_keys: teacher_ssh_public_keys,
      ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints: ssh_exercise_vm_sha256_host_key_fingerprints,
      expected_server_properties: expected_server_properties,
      expected_server_properties_id: expected_server_properties.id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec class_data_factory(map()) :: Types.class_data()
  def class_data_factory(attrs!) do
    {name, attrs!} =
      Map.pop_lazy(attrs!, :name, fn -> sequence(:class_name, &"Class #{&1}") end)

    {now, attrs!} = pop_now(attrs!)
    {start_date, end_date, attrs!} = pop_class_date_window(attrs!, now)

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)
    {teacher_ssh_public_keys, attrs!} = Map.pop(attrs!, :teacher_ssh_public_keys, [])

    {ssh_exercise_vm_md5_host_key_fingerprints, attrs!} =
      Map.pop_lazy(
        attrs!,
        :ssh_exercise_vm_md5_host_key_fingerprints,
        optionally(fn -> random_ssh_host_key_fingerprints(:md5) end)
      )

    {ssh_exercise_vm_sha256_host_key_fingerprints, attrs!} =
      Map.pop_lazy(
        attrs!,
        :ssh_exercise_vm_sha256_host_key_fingerprints,
        optionally(fn -> random_ssh_host_key_fingerprints(:sha256) end)
      )

    [] = Map.keys(attrs!)

    %{
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      teacher_ssh_public_keys: teacher_ssh_public_keys,
      ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints: ssh_exercise_vm_sha256_host_key_fingerprints
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

  @spec expected_server_properties_data_factory(map()) :: Types.expected_server_properties()
  def expected_server_properties_data_factory(attrs!) do
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

    %{
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

    {ssh_exercise_password, attrs!} =
      Map.pop_lazy(attrs!, :ssh_exercise_password, fn ->
        sequence(:ssh_exercise_password, &"ssh-password-#{&1}")
      end)

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

    {now, attrs!} = pop_now(attrs!)
    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!, now)

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
      ssh_exercise_password: ssh_exercise_password,
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

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)

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
      active: active,
      student: student,
      student_id: student_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp random_ssh_host_key_fingerprints(digest_alg) do
    1
    |> Range.new(Faker.random_between(1, 3))
    |> Enum.map_join("\n", fn _n ->
      SSHFactory.random_ssh_host_key_fingerprint_string(digest_alg)
    end)
  end

  # Pops the class date window from the given attributes, generating random but
  # valid `start_date`/`end_date` values that bracket the reference time. The
  # reference time defaults to the current time but can be overridden with a
  # `:now` attribute so that a class is active at a pinned instant (see
  # `docs/testing.md`).
  defp pop_class_date_window(attrs!, now) do
    today = DateTime.to_date(now)

    {start_date, attrs!} =
      Map.pop_lazy(
        attrs!,
        :start_date,
        optionally(fn -> Faker.Date.between(Date.add(today, -365), today) end)
      )

    {end_date, attrs!} =
      Map.pop_lazy(
        attrs!,
        :end_date,
        optionally(fn -> Faker.Date.between(today, Date.add(today, 365)) end)
      )

    {start_date, end_date, attrs!}
  end
end
