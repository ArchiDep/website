defmodule ArchiDep.Repo.Migrations.AddServerProperties do
  use Ecto.Migration

  def change do
    create table(:server_properties, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:hostname, :string)
      add(:machine_id, :string)
      add(:cpus, :integer)
      add(:cores, :integer)
      add(:vcpus, :integer)
      add(:memory, :integer)
      add(:swap, :integer)
      add(:system, :string)
      add(:architecture, :string)
      add(:os_family, :string)
      add(:distribution, :string)
      add(:distribution_release, :string)
      add(:distribution_version, :string)
    end

    alter table(:servers) do
      add(
        :expected_properties_id,
        references(:server_properties,
          type: :binary_id,
          on_update: :update_all,
          on_delete: :delete_all
        )
      )

      remove(:expected_cpus)
      remove(:expected_cores)
      remove(:expected_vcpus)
      remove(:expected_memory)
      remove(:expected_swap)
      remove(:expected_system)
      remove(:expected_architecture)
      remove(:expected_os_family)
      remove(:expected_distribution)
      remove(:expected_distribution_release)
      remove(:expected_distribution_version)
    end

    create unique_index(:servers, [:expected_properties_id],
             name: :servers_unnique_expected_properties
           )
  end
end
