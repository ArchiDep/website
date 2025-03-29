defmodule ArchiDepWeb.Admin.Classes.CreateClassForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean, default: true)
  end

  @spec changeset(map) :: Changeset.t(t())
  def changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [:name, :start_date, :end_date, :active])
    |> validate_required([:name, :active])
  end
end
