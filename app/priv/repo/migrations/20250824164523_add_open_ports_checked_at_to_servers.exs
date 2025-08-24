defmodule ArchiDep.Repo.Migrations.AddOpenPortsCheckedAtToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :open_ports_checked_at, :utc_datetime_usec
    end
  end
end
