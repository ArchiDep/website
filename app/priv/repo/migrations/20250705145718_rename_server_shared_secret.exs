defmodule ArchiDep.Repo.Migrations.RenameServerSharedSecret do
  use Ecto.Migration

  def change do
    rename table(:servers), :shared_secret, to: :secret_key
  end
end
