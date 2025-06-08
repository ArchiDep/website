defmodule ArchiDep.Repo.Migrations.AddServers do
  use Ecto.Migration

  def change do
    create table(:servers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: true, size: 50
      add :ip_address, :inet, null: false
      add :username, :string, null: true, size: 32
      add :version, :bigint, null: false

      add :user_account_id,
          references(:user_accounts,
            type: :binary_id,
            on_delete: :restrict,
            on_update: :update_all
          ),
          null: false

      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    create unique_index(:servers, :ip_address, name: :servers_unique_ip_address)

    create constraint(:servers, :version_is_positive, check: "version >= 1")
  end
end
