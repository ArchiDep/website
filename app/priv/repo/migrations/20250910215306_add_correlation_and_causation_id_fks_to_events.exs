defmodule ArchiDep.Repo.Migrations.AddCorrelationAndCausationIdFksToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      modify :correlation_id,
             references(:events, type: :uuid, on_update: :update_all, on_delete: :restrict)

      modify :causation_id,
             references(:events, type: :uuid, on_update: :update_all, on_delete: :restrict)
    end
  end
end
