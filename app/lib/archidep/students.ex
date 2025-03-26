defmodule ArchiDep.Students do
  use ArchiDep, :context

  @behaviour ArchiDep.Students.Behaviour

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data), to: @implementation

  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: @implementation
end
