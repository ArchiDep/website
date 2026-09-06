defmodule ArchiDep.Repo.Migrations.ScopeServerUniquenessToClass do
  use Ecto.Migration

  # Servers are kept forever, including those of classes that have ended, so
  # neither an IP address nor a name may be reserved by a past class. Both
  # constraints gain the class: an address may only be registered once within a
  # class (two records for one machine would fight over it while both are
  # tracked), and a name only has to tell an owner's servers apart within the
  # class that lists them.
  #
  # `servers_unique_name` also gains the owner, which the application has always
  # validated against and the index never carried.

  def up do
    drop unique_index(:servers, [:ip_address], name: :servers_unique_ip_address)

    create unique_index(:servers, [:class_id, :ip_address], name: :servers_unique_ip_address)

    drop unique_index(:servers, [:name, :user_account_id], name: :servers_unique_name)

    create unique_index(:servers, [:class_id, :user_account_id, :name],
             name: :servers_unique_name
           )
  end

  def down do
    drop unique_index(:servers, [:class_id, :user_account_id, :name], name: :servers_unique_name)

    create unique_index(:servers, [:name, :user_account_id], name: :servers_unique_name)

    drop unique_index(:servers, [:class_id, :ip_address], name: :servers_unique_ip_address)

    create unique_index(:servers, [:ip_address], name: :servers_unique_ip_address)
  end
end
