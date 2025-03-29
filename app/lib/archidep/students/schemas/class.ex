defmodule ArchiDep.Students.Schemas.Class do
  @moduledoc """
  A class is a group of students participating in a specific instance of the
  course (e.g. the course for the 2024-2025 academic year).
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Students.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "classes" do
    field(:name, :binary)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec new(Types.class_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [:name, :start_date, :end_date, :active])
    |> change(
      id: id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate_length(:name, max: 50)
    |> validate_format(:name, ~r/\A\S.*\z/, message: "must not start with whitespace")
    |> validate_format(:name, ~r/\A.*\S\z/, message: "must not end with whitespace")
    |> validate_required([:name, :active])
    |> unique_constraint(:name, name: :classes_unique_name_index)
    |> validate_start_and_end_dates()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)

      from(c in __MODULE__,
        where: fragment("LOWER(?)", c.name) == fragment("LOWER(?)", ^name)
      )
    end)
  end

  defp validate_start_and_end_dates(changeset) do
    if changed?(changeset, :start_date) or changed?(changeset, :end_date) do
      validate_start_and_end_dates(
        changeset,
        get_field(changeset, :start_date),
        get_field(changeset, :end_date)
      )
    else
      changeset
    end
  end

  defp validate_start_and_end_dates(changeset, nil, _end_date) do
    changeset
  end

  defp validate_start_and_end_dates(changeset, _start_date, nil) do
    changeset
  end

  defp validate_start_and_end_dates(changeset, start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :end_date, "must be after the start date")
    else
      changeset
    end
  end
end
