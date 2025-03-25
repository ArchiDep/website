defmodule ArchiDep.Students.ListClasses do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class

  @spec list_classes(Authentication.t()) :: list(Class.t())
  def list_classes(auth) do
    authorize!(auth, Policy, :students, :list_classes, nil)

    Repo.all(from c in Class, order_by: c.name)
  end
end
