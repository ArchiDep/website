defmodule ArchiDep.Repo.Migrations.FixAnsiblePlaybookRunsStartedAtConstraint do
  use Ecto.Migration

  def up do
    drop(constraint(:ansible_playbook_runs, :started_at_present_if_running))

    create(
      constraint(:ansible_playbook_runs, :started_at_present_if_running,
        check:
          "state = 'interrupted' OR state = 'pending' OR state = 'timeout' OR started_at IS NOT NULL"
      )
    )
  end

  def down do
    drop(constraint(:ansible_playbook_runs, :started_at_present_if_running))

    create(
      constraint(:ansible_playbook_runs, :started_at_present_if_running,
        check: "state = 'pending' OR started_at IS NOT NULL"
      )
    )
  end
end
