defmodule ArchiDep.Students.Schemas.Student do
  use ArchiDep, :schema

  alias ArchiDep.Students.Schemas.Class

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:name, :binary)
    field(:email, :binary)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    belongs_to(:class, Class)
  end
end
