defmodule ArchiDep.Repo.Migrations.AddMorePrecisionToServerSetUpAt do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      modify :set_up_at, :utc_datetime_usec, null: true, from: {:utc_datetime, null: true}
    end
  end
end
