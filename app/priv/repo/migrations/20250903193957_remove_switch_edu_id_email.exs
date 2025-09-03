defmodule ArchiDep.Repo.Migrations.RenameSwitchEduIdEmailToMatchedEmail do
  use Ecto.Migration

  def up do
    alter table(:switch_edu_ids) do
      remove :email
    end
  end

  def down do
    alter table(:switch_edu_ids) do
      add :email, :string, null: false
    end

    create unique_index(:switch_edu_ids, [:email], name: :switch_edu_ids_unique_email_index)
  end
end
