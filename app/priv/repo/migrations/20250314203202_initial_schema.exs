defmodule ArchiDep.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  def change do
    execute ~s/CREATE EXTENSION "uuid-ossp";/, ~s/DROP EXTENSION "uuid-ossp";/

    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :stream, :text, null: false
      add :version, :bigint, null: false
      add :type, :text, null: false
      add :data, :map, null: false
      add :meta, :map, null: false
      add :initiator, :text
      add :causation_id, :uuid, null: false
      add :correlation_id, :uuid, null: false
      add :occurred_at, :utc_datetime_usec, null: false
    end

    create index(:events, [:occurred_at])
    create index(:events, [:initiator], name: :events_initiator_index)

    create constraint(:events, :correlation_and_causation_id_are_consistent,
             check: """
             (id = causation_id) = (id = correlation_id)
             """
           )

    create table(:switch_edu_ids, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :text, null: false
      add :first_name, :text, null: false
      add :last_name, :text
      add :swiss_edu_person_unique_id, :text, null: false
      add :version, :bigint, null: false
      add :used_at, :utc_datetime_usec, null: false
      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    create constraint(:switch_edu_ids, :created_at_and_updated_at_are_consistent,
             check: """
             updated_at >= created_at
             """
           )

    create constraint(:switch_edu_ids, :created_at_and_used_at_are_consistent,
             check: """
             used_at >= created_at
             """
           )

    create unique_index(:switch_edu_ids, [:email], name: :switch_edu_ids_unique_email_index)

    create unique_index(:switch_edu_ids, [:swiss_edu_person_unique_id],
             name: :switch_edu_ids_unique_sepui_index
           )

    create table(:user_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :string, null: false, size: 25
      add :roles, {:array, :string}, null: false, size: 25

      add :switch_edu_id_id,
          references(:switch_edu_ids,
            type: :binary_id,
            on_delete: :restrict,
            on_update: :update_all
          ),
          null: false

      add :version, :bigint, null: false
      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    create unique_index(:user_accounts, [:switch_edu_id_id],
             name: :user_accounts_unique_switch_edu_id_index
           )

    create unique_index(:user_accounts, ["LOWER(username)"],
             name: :user_accounts_unique_username_index
           )

    create constraint(:user_accounts, :version_is_positive, check: "version >= 1")

    create table(:user_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token, :binary, null: false
      add :used_at, :utc_datetime_usec
      add :client_ip_address, :string, size: 50
      add :client_user_agent, :text

      add :user_account_id,
          references(:user_accounts,
            type: :binary_id,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false

      timestamps(
        inserted_at: :created_at,
        updated_at: false,
        required: true,
        type: :utc_datetime_usec
      )
    end

    create unique_index(:user_sessions, [:token])
  end
end
