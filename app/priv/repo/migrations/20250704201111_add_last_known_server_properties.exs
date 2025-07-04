defmodule ArchiDep.Repo.Migrations.AddLastKnownServerProperties do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      modify(
        :expected_server_properties_id,
        references(:server_properties,
          type: :binary_id,
          on_update: :update_all,
          on_delete: :restrict
        ),
        null: false,
        from:
          {references(:server_properties,
             type: :binary_id,
             on_update: :update_all,
             on_delete: :restrict
           ), null: true}
      )
    end

    alter table(:servers) do
      modify(
        :expected_properties_id,
        references(:server_properties,
          type: :binary_id,
          on_update: :update_all,
          on_delete: :restrict
        ),
        null: false,
        from:
          {references(:server_properties,
             type: :binary_id,
             on_update: :update_all,
             on_delete: :delete_all
           ), null: true}
      )

      add(
        :last_known_properties_id,
        references(:server_properties,
          type: :binary_id,
          on_update: :update_all,
          on_delete: :restrict
        )
      )
    end

    create unique_index(:servers, [:last_known_properties_id],
             name: :servers_unique_last_known_properties
           )
  end
end
