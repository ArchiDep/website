defmodule ArchiDep.Repo.Migrations.AddAnsibleVariablesToAnsiblePlaybookRuns do
  use Ecto.Migration

  def up do
    alter table(:ansible_playbook_runs) do
      add(:vars, :map, default: %{}, null: false)
    end

    alter table(:ansible_playbook_runs) do
      modify(:vars, :map, default: nil, null: false)
    end
  end

  def down do
    alter table(:ansible_playbook_runs) do
      remove(:vars)
    end
  end
end
