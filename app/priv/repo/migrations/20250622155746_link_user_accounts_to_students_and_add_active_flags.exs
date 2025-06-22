defmodule ArchiDep.Repo.Migrations.LinkUserAccountsToStudentsAndAddActiveFlags do
  use Ecto.Migration

  def up do
    alter table(:servers) do
      add(:active, :boolean)
    end

    execute("UPDATE servers SET active = true;")

    alter table(:servers) do
      modify(:active, :boolean, null: false)
    end

    alter table(:students) do
      add(:active, :boolean)
    end

    execute("UPDATE students SET active = true;")

    alter table(:students) do
      modify(:active, :boolean, null: false)
    end

    alter table(:user_accounts) do
      add(
        :student_id,
        references(:students, type: :binary_id, on_update: :update_all, on_delete: :nilify_all)
      )

      add(:active, :boolean)
    end

    execute("UPDATE user_accounts SET active = true;")

    execute(
      "UPDATE user_accounts AS ua SET student_id = s.id FROM students s WHERE s.user_account_id = ua.id;"
    )

    alter table(:user_accounts) do
      modify(:active, :boolean, null: false)
      remove(:class_id)
    end

    create index(:user_accounts, [:student_id], unique: true)
  end

  def down do
    alter table(:servers) do
      remove(:active)
    end

    alter table(:students) do
      remove(:active)
    end

    alter table(:user_accounts) do
      add :class_id,
          references(:classes,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :restrict
          ),
          null: true
    end

    execute(
      "UPDATE user_accounts AS ua SET class_id = c.id FROM students s INNER JOIN classes c ON s.class_id = c.id WHERE ua.student_id = s.id;"
    )

    alter table(:user_accounts) do
      remove(:active)
      remove(:student_id)
    end
  end
end
