defmodule ArchiDep.Repo.Migrations.AddStudentsContext do
  use Ecto.Migration

  def change do
    create table(:classes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false, size: 50
      add :start_date, :date
      add :end_date, :date
      add :active, :boolean, null: false
      add :version, :bigint, null: false
      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    create unique_index(:classes, [:name], name: :classes_unique_name_index)
    create constraint(:classes, :version_is_positive, check: "version >= 1")

    create constraint(:classes, :dates_are_consistent,
             check: "start_date is null or end_date is null or start_date <= end_date"
           )

    create table(:students, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false, size: 200
      add :email, :text, null: false
      add :version, :bigint, null: false

      add :class_id,
          references(:classes,
            type: :binary_id,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false

      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    create unique_index(:students, [:class_id, :email], name: :students_unique_email_index)
    create constraint(:students, :version_is_positive, check: "version >= 1")

    alter table(:user_accounts, primary_key: false) do
      add :student_id,
          references(:students,
            type: :binary_id,
            on_delete: :nilify_all,
            on_update: :update_all
          )
    end
  end
end
