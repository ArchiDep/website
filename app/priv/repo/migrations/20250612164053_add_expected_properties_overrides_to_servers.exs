defmodule ArchiDep.Repo.Migrations.AddExpectedPropertiesOverridesToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add(:expected_cpus, :smallint)
      add(:expected_cores, :smallint)
      add(:expected_vcpus, :smallint)
      add(:expected_memory, :integer)
      add(:expected_swap, :integer)
      add(:expected_architecture, :string, size: 20)
      add(:expected_system, :string, size: 50)
      add(:expected_os_family, :string, size: 50)
      add(:expected_distribution, :string, size: 50)
      add(:expected_distribution_release, :string, size: 50)
      add(:expected_distribution_version, :string, size: 20)
    end

    create constraint(:servers, :expected_cpus_positive,
             check: "expected_cpus IS NULL OR expected_cpus >= 0"
           )

    create constraint(:servers, :expected_cores_positive,
             check: "expected_cores IS NULL OR expected_cores >= 0"
           )

    create constraint(:servers, :expected_vcpus_positive,
             check: "expected_vcpus IS NULL OR expected_vcpus >= 0"
           )

    create constraint(:servers, :expected_memory_positive,
             check: "expected_memory IS NULL OR expected_memory >= 0"
           )

    create constraint(:servers, :expected_swap_positive,
             check: "expected_swap IS NULL OR expected_swap >= 0"
           )

    create constraint(:servers, :expected_architecture_not_empty,
             check: "expected_architecture IS NULL OR expected_architecture <> ''"
           )

    create constraint(:servers, :expected_system_not_empty,
             check: "expected_system IS NULL OR expected_system <> ''"
           )

    create constraint(:servers, :expected_os_family_not_empty,
             check: "expected_os_family IS NULL OR expected_os_family <> ''"
           )

    create constraint(:servers, :expected_distribution_not_empty,
             check: "expected_distribution IS NULL OR expected_distribution <> ''"
           )

    create constraint(:servers, :expected_distribution_release_not_empty,
             check: "expected_distribution_release IS NULL OR expected_distribution_release <> ''"
           )

    create constraint(:servers, :expected_distribution_version_not_empty,
             check: "expected_distribution_version IS NULL OR expected_distribution_version <> ''"
           )
  end
end
