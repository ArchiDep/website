defmodule ArchiDep.Repo.Migrations.AddExpectedServerPropertiesToClasses do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      add(:expected_server_cpus, :smallint)
      add(:expected_server_cores, :smallint)
      add(:expected_server_vcpus, :smallint)
      add(:expected_server_memory, :integer)
      add(:expected_server_swap, :integer)
      add(:expected_server_architecture, :string, size: 20)
      add(:expected_server_system, :string, size: 50)
      add(:expected_server_os_family, :string, size: 50)
      add(:expected_server_distribution, :string, size: 50)
      add(:expected_server_distribution_release, :string, size: 50)
      add(:expected_server_distribution_version, :string, size: 20)
    end

    create constraint(:classes, :expected_server_cpus_positive,
             check: "expected_server_cpus IS NULL OR expected_server_cpus >= 1"
           )

    create constraint(:classes, :expected_server_cores_positive,
             check: "expected_server_cores IS NULL OR expected_server_cores >= 1"
           )

    create constraint(:classes, :expected_server_vcpus_positive,
             check: "expected_server_vcpus IS NULL OR expected_server_vcpus >= 1"
           )

    create constraint(:classes, :expected_server_memory_positive,
             check: "expected_server_memory IS NULL OR expected_server_memory >= 1"
           )

    create constraint(:classes, :expected_server_swap_positive,
             check: "expected_server_swap IS NULL OR expected_server_swap >= 1"
           )

    create constraint(:classes, :expected_server_architecture_not_empty,
             check: "expected_server_architecture IS NULL OR expected_server_architecture <> ''"
           )

    create constraint(:classes, :expected_server_system_not_empty,
             check: "expected_server_system IS NULL OR expected_server_system <> ''"
           )

    create constraint(:classes, :expected_server_os_family_not_empty,
             check: "expected_server_os_family IS NULL OR expected_server_os_family <> ''"
           )

    create constraint(:classes, :expected_server_distribution_not_empty,
             check: "expected_server_distribution IS NULL OR expected_server_distribution <> ''"
           )

    create constraint(:classes, :expected_server_distribution_release_not_empty,
             check:
               "expected_server_distribution_release IS NULL OR expected_server_distribution_release <> ''"
           )

    create constraint(:classes, :expected_server_distribution_version_not_empty,
             check:
               "expected_server_distribution_version IS NULL OR expected_server_distribution_version <> ''"
           )
  end
end
