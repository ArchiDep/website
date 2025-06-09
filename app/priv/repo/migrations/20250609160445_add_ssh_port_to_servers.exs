defmodule ArchiDep.Repo.Migrations.AddSshPortToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add(:ssh_port, :integer, null: true)
    end

    create constraint(:servers, :ssh_port_must_be_valid,
             check: "ssh_port IS NULL OR (ssh_port >= 1 AND ssh_port <= 65535)"
           )
  end
end
