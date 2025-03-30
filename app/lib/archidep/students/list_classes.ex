defmodule ArchiDep.Students.ListClasses do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class

  @spec list_classes(Authentication.t()) :: list(Class.t())
  def list_classes(auth) do
    authorize!(auth, Policy, :students, :list_classes, nil)

    Repo.all(
      from c in Class,
        order_by: [desc: c.active, desc: c.end_date, desc: c.created_at, asc: c.name]
    )
  end
end
