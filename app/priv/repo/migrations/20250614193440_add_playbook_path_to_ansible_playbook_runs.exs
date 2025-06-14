defmodule ArchiDep.Repo.Migrations.AddPlaybookPathToAnsiblePlaybookRuns do
  use Ecto.Migration

  def change do
    alter table(:ansible_playbook_runs) do
      add(:playbook_path, :string, null: false)
    end
  end
end
