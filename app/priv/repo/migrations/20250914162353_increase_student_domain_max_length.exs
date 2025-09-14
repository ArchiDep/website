defmodule ArchiDep.Repo.Migrations.IncreaseStudentDomainMaxLength do
  use Ecto.Migration

  def change do
    alter table(:students) do
      modify :domain, :string, size: 50, null: false, from: {:string, size: 20, null: false}
    end
  end
end
