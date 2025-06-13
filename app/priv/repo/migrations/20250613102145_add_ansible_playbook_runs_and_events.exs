defmodule ArchiDep.Repo.Migrations.AddAnsiblePlaybookRunsAndEvents do
  use Ecto.Migration

  def change do
    create table(:ansible_playbook_runs) do
      add :playbook, :string, null: false, size: 50
      add :digest, :binary, null: false
      add :host, :inet, null: false
      add :port, :integer, null: false
      add :user, :string, null: false, size: 32

      add :server_id,
          references(:servers,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :delete_all
          ),
          null: true

      add :state, :string, null: false, size: 20
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec
      add :number_of_events, :smallint, null: false, default: 0
      add :last_event_at, :utc_datetime_usec
      add :exit_code, :integer
      add :stats_changed, :smallint, null: false, default: 0
      add :stats_failures, :smallint, null: false, default: 0
      add :stats_ignored, :smallint, null: false, default: 0
      add :stats_ok, :smallint, null: false, default: 0
      add :stats_rescued, :smallint, null: false, default: 0
      add :stats_skipped, :smallint, null: false, default: 0
      add :stats_unreachable, :smallint, null: false, default: 0

      timestamps(
        inserted_at: :created_at,
        required: true,
        type: :utc_datetime_usec
      )
    end

    create constraint(:ansible_playbook_runs, :finished_at_is_after_started_at,
             check: "finished_at IS NULL OR started_at <= finished_at"
           )

    create constraint(:ansible_playbook_runs, :number_of_events_is_non_negative,
             check: "number_of_events >= 0"
           )

    create constraint(:ansible_playbook_runs, :exit_code_is_non_negative, check: "exit_code >= 0")

    create constraint(:ansible_playbook_runs, :stats_changed_is_non_negative,
             check: "stats_changed >= 0"
           )

    create constraint(:ansible_playbook_runs, :stats_failures_is_non_negative,
             check: "stats_failures >= 0"
           )

    create constraint(:ansible_playbook_runs, :stats_ignored_is_non_negative,
             check: "stats_ignored >= 0"
           )

    create constraint(:ansible_playbook_runs, :stats_ok_is_non_negative, check: "stats_ok >= 0")

    create constraint(:ansible_playbook_runs, :stats_rescued_is_non_negative,
             check: "stats_rescued >= 0"
           )

    create constraint(:ansible_playbook_runs, :stats_skipped_is_non_negative,
             check: "stats_skipped >= 0"
           )

    create constraint(:ansible_playbook_runs, :stats_unreachable_is_non_negative,
             check: "stats_unreachable >= 0"
           )

    create table(:ansible_playbook_events) do
      add :run_id,
          references(:ansible_playbook_runs, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :action, :string, null: true
      add :changed, :boolean, null: false, default: false
      add :data, :jsonb, null: false
      add :task_name, :string, null: true
      add :task_id, :string, null: true
      add :task_started_at, :utc_datetime_usec, null: true
      add :task_ended_at, :utc_datetime_usec, null: true
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(
        inserted_at: :created_at,
        updated_at: false,
        required: true,
        type: :utc_datetime_usec
      )
    end

    create index(:ansible_playbook_events, [:run_id, "created_at DESC"])
  end
end
