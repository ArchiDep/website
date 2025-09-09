defmodule ArchiDep.Repo.Migrations.AddSshExerciseVmIpAddressToClasses do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      add :ssh_exercise_vm_ip_address, :inet
    end
  end
end
