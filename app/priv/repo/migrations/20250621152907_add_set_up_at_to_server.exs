defmodule ArchiDep.Repo.Migrations.AddSetUpAtToServer do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :set_up_at, :utc_datetime, null: true
    end
  end
end
