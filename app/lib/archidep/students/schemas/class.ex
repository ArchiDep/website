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
          # Common metadata
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

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, start_date: start_date, end_date: end_date}, now),
    do:
      active and
        (is_nil(start_date) or now |> DateTime.to_date() |> Date.compare(start_date) != :lt) and
        (is_nil(end_date) or now |> DateTime.to_date() |> Date.compare(end_date) != :gt)

  @spec fetch_class(UUID.t()) :: {:ok, t()} | {:error, :class_not_found}
  def fetch_class(id) do
    case Repo.one(from c in __MODULE__, where: c.id == ^id) do
      nil ->
        {:error, :class_not_found}

      class ->
        {:ok, class}
    end
  end

  @spec new(Types.class_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :start_date,
      :end_date,
      :active
    ])
    |> change(
      id: id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)

      from(c in __MODULE__,
        where: fragment("LOWER(?)", c.name) == fragment("LOWER(?)", ^name)
      )
    end)
  end

  @spec update(__MODULE__.t(), Types.class_data()) :: Changeset.t(t())
  def update(class, data) do
    id = class.id
    now = DateTime.utc_now()

    class
    |> cast(data, [
      :name,
      :start_date,
      :end_date,
      :active
    ])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)

      from(c in __MODULE__,
        where: c.id != ^id and fragment("LOWER(?)", c.name) == fragment("LOWER(?)", ^name)
      )
    end)
  end

  @spec delete(__MODULE__.t()) :: Changeset.t(t())
  def delete(class) do
    class
    |> change()
    |> foreign_key_constraint(:servers,
      name: :servers_class_id_fkey,
      message: "class has servers"
    )
  end

  defp validate(changeset) do
    changeset
    |> update_change(:name, &trim/1)
    |> validate_required([:name, :active])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name, name: :classes_unique_name_index)
    |> validate_start_and_end_dates()
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
