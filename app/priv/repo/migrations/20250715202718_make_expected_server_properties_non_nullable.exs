defmodule ArchiDep.Repo.Migrations.MakeExpectedServerPropertiesNonNullable do
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
  end
end
