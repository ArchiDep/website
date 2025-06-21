defmodule ArchiDep.Repo.Migrations.AddGitRevisionToAnsiblePlaybookRuns do
  use Ecto.Migration

  def change do
    alter table(:ansible_playbook_runs) do
      add :git_revision, :string, null: false
    end
  end
end
