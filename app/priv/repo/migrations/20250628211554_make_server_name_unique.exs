defmodule ArchiDep.Repo.Migrations.MakeServerNameUnique do
  use Ecto.Migration

  def change do
    create unique_index(:servers, [:name, :user_account_id], name: :servers_unique_name)
  end
end
