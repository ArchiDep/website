defmodule ArchiDep.Students.Behaviour do
  use ArchiDep, :behaviour

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @callback validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()

  @callback create_class(Authentication.t(), Types.class_data()) ::
              {:ok, Class.t()} | {:error, Changeset.t()}

  @callback list_classes(Authentication.t()) :: list(Class.t())
end
