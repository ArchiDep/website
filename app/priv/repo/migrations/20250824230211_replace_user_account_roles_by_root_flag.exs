defmodule ArchiDep.Repo.Migrations.ReplaceUserAccountRolesByRootFlag do
  use Ecto.Migration

  def up do
    alter table(:user_accounts) do
      add :root, :boolean, default: false, null: false
    end

    execute("""
    UPDATE user_accounts SET root = true WHERE 'root' = ANY(roles);
    """)

    alter table(:user_accounts) do
      remove :roles
    end
  end

  def down do
    alter table(:user_accounts) do
      add :roles, {:array, :string}, default: "{}", null: false
    end

    execute("""
    UPDATE user_accounts SET roles = array_append(roles, 'root') WHERE root = true;
    """)

    execute("""
    UPDATE user_accounts SET roles = array_append(roles, 'student') WHERE root = false;
    """)

    alter table(:user_accounts) do
      remove :root
    end
  end
end
