defmodule ArchiDepWeb.Admin.Classes.ImportStudentsForm do
  use Ecto.Schema

  use Gettext, backend: ArchiDepWeb.Gettext
  import ArchiDep.Helpers.DataHelpers, only: [looks_like_an_email?: 1]
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name_column: String.t(),
          email_column: String.t(),
          academic_class: String.t() | nil,
          domain: String.t()
        }

  @primary_key false
  embedded_schema do
    field(:name_column, :string)
    field(:email_column, :string)
    field(:academic_class, :string)
    field(:domain, :string, default: "")
  end

  @spec changeset(map, list(map)) :: Changeset.t(t())
  @spec changeset(%{optional(:__struct__) => none(), optional(atom() | binary()) => any()}) ::
          Ecto.Changeset.t()
  def changeset(params \\ %{}, students \\ []) when is_map(params) and is_list(students) do
    %__MODULE__{}
    |> cast(params, [:name_column, :email_column, :academic_class, :domain])
    |> validate_required([:name_column, :email_column, :domain])
    |> validate_change(:name_column, fn :name_column, name_column ->
      unique_student_names = students |> Enum.map(& &1[name_column]) |> Enum.uniq()

      cond do
        Enum.all?(students, &looks_like_an_email?(&1[name_column])) ->
          [name_column: gettext("this column looks like it contains emails, not names")]

        (students |> Enum.map(& &1[name_column]) |> Enum.uniq() |> length()) / length(students) <
            0.9 ->
          [
            name_column:
              gettext(
                "only {count} unique {count, plural, =1 {name} other {names}} out of {total} in this column",
                count: length(unique_student_names),
                total: length(students)
              )
          ]

        true ->
          []
      end
    end)
    |> validate_change(:email_column, fn :email_column, email_column ->
      cond do
        !Enum.any?(students, &looks_like_an_email?(&1[email_column])) ->
          [email_column: gettext("no email found in this column")]

        students |> Enum.map(fn student -> student[email_column] end) |> Enum.uniq() |> length() !=
            length(students) ->
          [email_column: gettext("duplicate emails found in this column")]

        true ->
          []
      end
    end)
  end
end
