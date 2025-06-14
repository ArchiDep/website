defmodule ArchiDep.Repo.Migrations.MakeAnsiblePlaybookRunStartedAtNullable do
  use Ecto.Migration

  def change do
    alter table(:ansible_playbook_runs) do
      modify :started_at, :utc_datetime_usec, null: true, from: {:utc_datetime_usec, null: false}
    end

    create constraint(:ansible_playbook_runs, :started_at_present_if_running,
             check: "state = 'pending' OR started_at IS NOT NULL"
           )
  end
end
