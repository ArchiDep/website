defmodule ArchiDep.Repo.Migrations.AddSharedSecretToServer do
  use Ecto.Migration

  def up do
    execute ~s/CREATE EXTENSION "pgcrypto";/

    alter table(:servers) do
      add :shared_secret, :binary
    end

    execute("UPDATE servers SET shared_secret = gen_random_bytes(50);")

    alter table(:servers) do
      modify :shared_secret, :binary, null: false
    end

    create unique_index(:servers, [:shared_secret], name: :servers_shared_secret_unique)
  end

  def down do
    alter table(:servers) do
      remove :shared_secret
    end

    execute ~s/DROP EXTENSION "pgcrypto";/
  end
end
