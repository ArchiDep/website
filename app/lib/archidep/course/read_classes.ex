defmodule ArchiDep.Course.ReadClasses do
  use ArchiDep, :use_case

  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.Schemas.Class

  @spec fetch_class(Authentication.t(), UUID.t()) :: {:ok, Class.t()} | {:error, :class_not_found}
  def fetch_class(auth, id) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id),
         :ok <- authorize(auth, Policy, :course, :fetch_class, class) do
      {:ok, class}
    else
      {:error, :class_not_found} ->
        {:error, :class_not_found}

      {:error, {:access_denied, :course, :fetch_class}} ->
        {:error, :class_not_found}
    end
  end

  @spec list_classes(Authentication.t()) :: list(Class.t())
  def list_classes(auth) do
    authorize!(auth, Policy, :course, :list_classes, nil)

    Repo.all(
      from c in Class,
        order_by: [desc: c.active, desc: c.end_date, desc: c.created_at, asc: c.name]
    )
  end
end
