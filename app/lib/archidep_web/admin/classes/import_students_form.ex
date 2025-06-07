defmodule ArchiDepWeb.Admin.Classes.ImportStudentsForm do
  use Ecto.Schema

  import ArchiDep.Helpers.DataHelpers, only: [looks_like_an_email?: 1]
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name_column: String.t(),
          email_column: String.t()
        }

  @primary_key false
  embedded_schema do
    field(:name_column, :string)
    field(:email_column, :string)
  end

  @spec changeset(map, list(map)) :: Changeset.t(t())
  @spec changeset(%{optional(:__struct__) => none(), optional(atom() | binary()) => any()}) ::
          Ecto.Changeset.t()
  def changeset(params \\ %{}, students \\ []) when is_map(params) and is_list(students) do
    %__MODULE__{}
    |> cast(params, [:name_column, :email_column])
    |> validate_required([:name_column, :email_column])
    |> validate_change(:email_column, fn :email_column, email_column ->
      cond do
        !Enum.any?(students, &looks_like_an_email?(&1[email_column])) ->
          [email_column: "no email found in this column"]

        students |> Enum.map(fn student -> student[email_column] end) |> Enum.uniq() |> length() !=
            length(students) ->
          [email_column: "duplicate emails found in this column"]

        true ->
          []
      end
    end)
  end
end
