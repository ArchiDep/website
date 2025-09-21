defmodule ArchiDep.Repo.Migrations.AddSshHostKeyFingerprintsToServers do
  use Ecto.Migration

  def up do
    alter table(:servers) do
      add :ssh_host_key_fingerprints, :text
    end

    execute "UPDATE servers SET ssh_host_key_fingerprints = '(no keys defined)' WHERE ssh_host_key_fingerprints IS NULL;"

    alter table(:servers) do
      modify :ssh_host_key_fingerprints, :text, null: false
    end
  end

  def down do
    alter table(:servers) do
      remove :ssh_host_key_fingerprints
    end
  end
end
