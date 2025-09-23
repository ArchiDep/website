defmodule ArchiDep.Repo.Migrations.AddSshExerciseVmHostKeyFingerprintsToClasses do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      add(:ssh_exercise_vm_host_key_fingerprints, :text)
    end
  end
end
