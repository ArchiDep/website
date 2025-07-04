defmodule ArchiDep.Repo.Migrations.UseServerPropertiesForClasses do
  use Ecto.Migration

  def change do
    drop unique_index(:servers, [:expected_properties_id],
           name: :servers_unnique_expected_properties
         )

    create unique_index(:servers, [:expected_properties_id],
             name: :servers_unique_expected_properties
           )

    alter table(:classes) do
      add(
        :expected_server_properties_id,
        references(:server_properties,
          type: :binary_id,
          on_update: :update_all,
          on_delete: :restrict
        )
      )

      remove(:expected_server_cpus)
      remove(:expected_server_cores)
      remove(:expected_server_vcpus)
      remove(:expected_server_memory)
      remove(:expected_server_swap)
      remove(:expected_server_system)
      remove(:expected_server_architecture)
      remove(:expected_server_os_family)
      remove(:expected_server_distribution)
      remove(:expected_server_distribution_release)
      remove(:expected_server_distribution_version)
    end

    create unique_index(:classes, [:expected_server_properties_id],
             name: :classes_unique_expected_server_properties
           )
  end
end
