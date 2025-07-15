defmodule ArchiDep.Repo.Migrations.RemoveSuggestedUsername do
  use Ecto.Migration

  def change do
    alter table(:students) do
      remove :suggested_username, :string
    end
  end
end
