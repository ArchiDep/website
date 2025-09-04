defmodule ArchiDep.Repo.Migrations.ReplaceUserAccountUsernameByEmail do
  use Ecto.Migration

  def up do
    drop unique_index(:user_accounts, :unique_username)

    alter table(:user_accounts) do
      modify(:username, :text, null: true, from: {:string, size: 25, null: false})
    end
  end

  def down do
    alter table(:user_accounts) do
      modify(:username, :string, size: 25, null: false, from: :text)
    end

    create unique_index(:user_accounts, :username, name: :user_accounts_unique_username_index)
  end
end
