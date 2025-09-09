defmodule ArchiDep.Repo.Migrations.AddSshExercisePasswordToStudents do
  use Ecto.Migration

  def up do
    alter table(:students) do
      add :ssh_exercise_password, :string
    end

    # execute a query to set the ssh exercise password to a random alphanumeric string for existing records in PostgreSQL
    execute("""
    UPDATE students
    SET ssh_exercise_password = (
      SELECT string_agg(
        substr(
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
          ceil(random() * 62)::integer,
          1
        ), ''
      )
      FROM generate_series(1, 8)
    );
    """)

    alter table(:students) do
      modify :ssh_exercise_password, :string, null: false
    end
  end

  def down do
    alter table(:students) do
      remove :ssh_exercise_password
    end
  end
end
