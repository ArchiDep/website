defmodule ArchiDep.Repo.Migrations.AddSshExerciseVmMd5HostKeyFingerprintsToClasses do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      add(:ssh_exercise_vm_md5_host_key_fingerprints, :text)
    end

    rename(
      table(:classes),
      :ssh_exercise_vm_host_key_fingerprints,
      to: :ssh_exercise_vm_sha256_host_key_fingerprints
    )
  end
end
