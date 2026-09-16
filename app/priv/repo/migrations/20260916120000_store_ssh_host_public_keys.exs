defmodule ArchiDep.Repo.Migrations.StoreSshHostPublicKeys do
  use Ecto.Migration

  # Host key fingerprints cannot be turned back into the keys they were computed
  # from, so no server or class has keys after this migration. A server cannot
  # be active without keys, so every server is deactivated, and the active
  # server counters are reset to match. This is done directly in the database:
  # no event records the deactivation.

  def up do
    alter table(:servers) do
      add :ssh_host_keys, :text
    end

    execute("UPDATE servers SET active = false WHERE active;")
    execute("UPDATE server_owner_counters SET active_server_count = 0;")

    create constraint(:servers, :active_server_has_ssh_host_keys,
             check: "NOT active OR ssh_host_keys IS NOT NULL"
           )

    alter table(:servers) do
      remove :ssh_host_key_fingerprints
    end

    alter table(:classes) do
      add :ssh_exercise_vm_host_keys, :text
      remove :ssh_exercise_vm_md5_host_key_fingerprints
      remove :ssh_exercise_vm_sha256_host_key_fingerprints
    end
  end

  def down do
    alter table(:classes) do
      add :ssh_exercise_vm_md5_host_key_fingerprints, :text
      add :ssh_exercise_vm_sha256_host_key_fingerprints, :text
      remove :ssh_exercise_vm_host_keys
    end

    drop constraint(:servers, :active_server_has_ssh_host_keys)

    alter table(:servers) do
      add :ssh_host_key_fingerprints, :text, null: false, default: "(no keys defined)"
      remove :ssh_host_keys
    end

    alter table(:servers) do
      modify :ssh_host_key_fingerprints, :text, null: false, default: nil
    end
  end
end
