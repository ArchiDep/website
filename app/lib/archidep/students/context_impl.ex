defmodule ArchiDep.Students.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Students.CreateClass
  alias ArchiDep.Students.ListClasses
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @behaviour ArchiDep.Students.Behaviour

  @spec create_class(Authentication.t(), Types.class_data(), EventMetadata.t()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data, meta), to: CreateClass

  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: ListClasses
end
