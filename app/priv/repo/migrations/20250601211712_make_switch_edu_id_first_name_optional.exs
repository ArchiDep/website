defmodule ArchiDep.Repo.Migrations.MakeSwitchEduIdFirstNameOptional do
  use Ecto.Migration

  def change do
    alter table(:switch_edu_ids) do
      modify :first_name, :string, null: true, from: {:string, null: false}
    end
  end
end
