defmodule ArchiDep.Repo.Migrations.RemoveSshExerciseVmIpAddressFromClasses do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      remove :ssh_exercise_vm_ip_address
    end
  end
end
