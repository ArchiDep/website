defmodule ArchiDep.Students.FetchClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class

  @spec fetch_class(Authentication.t(), UUID.t()) :: {:ok, Class.t()} | {:error, :class_not_found}
  def fetch_class(auth, id) do
    with {:ok, class} <- Class.fetch_class(id),
         :ok <- authorize(auth, Policy, :students, :fetch_class, class) do
      {:ok, class}
    else
      {:error, {:access_denied, :students, :fetch_class}} ->
        {:error, :class_not_found}
    end
  end
end
