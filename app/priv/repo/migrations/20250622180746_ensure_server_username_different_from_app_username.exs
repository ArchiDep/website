defmodule ArchiDep.Repo.Migrations.EnsureServerUsernameDifferentFromAppUsername do
  use Ecto.Migration

  def change do
    create constraint(:servers, :username_different_from_app_username,
             check: "username != app_username"
           )
  end
end
