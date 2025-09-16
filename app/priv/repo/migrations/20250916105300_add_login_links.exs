defmodule ArchiDep.Repo.Migrations.AddLoginLinks do
  use Ecto.Migration

  def change do
    create table(:login_links, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token, :binary, null: false
      add :active, :boolean, null: false
      add :used_at, :utc_datetime_usec

      add :user_account_id,
          references(:user_accounts,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :delete_all
          )

      add :preregistered_user_id,
          references(:students,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :delete_all
          )

      timestamps(
        inserted_at: :created_at,
        updated_at: false,
        required: true,
        type: :utc_datetime_usec
      )
    end

    create unique_index(:login_links, [:token], name: :login_links_token_unique)

    create index(:login_links, [:token, :active, :used_at],
             name: :login_links_active_link_lookup_index
           )

    create constraint(:login_links, :login_links_user_account_or_preregistered_user_check,
             check: """
               (user_account_id IS NOT NULL) <> (preregistered_user_id IS NOT NULL)
             """
           )
  end
end
