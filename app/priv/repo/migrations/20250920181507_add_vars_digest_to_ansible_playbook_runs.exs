defmodule ArchiDep.Repo.Migrations.AddVarsDigestToAnsiblePlaybookRuns do
  use Ecto.Migration

  def up do
    alter table(:ansible_playbook_runs) do
      add :vars_digest, :binary
    end

    # Set the vars_digest column to a string with the null byte for all runs
    execute("UPDATE ansible_playbook_runs SET vars_digest = '\\x00'")

    alter table(:ansible_playbook_runs) do
      modify :vars_digest, :binary, null: false
    end

    rename table(:ansible_playbook_runs), :digest, to: :playbook_digest
  end

  def down do
    rename table(:ansible_playbook_runs), :playbook_digest, to: :digest

    alter table(:ansible_playbook_runs) do
      remove :vars_digest
    end
  end
end
