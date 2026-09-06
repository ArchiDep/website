defmodule ArchiDep.Course.Schemas.CourseSession do
  @moduledoc """
  One session of the course: the day it was taught, what it was called, and the
  sections and chapters it finished, set work on, and announced for the next
  one.

  ## The numbers are a record, not a reference

  A section's number (100, 200, …) and a chapter's (101, 402, …) share one
  space, and a session stores them as three plain lists. They are deliberately
  **not** validated against `ArchiDep.CourseSite.Material`: the course material
  is written as the course runs, so any chapter that has not been taught yet may
  be added, removed or renumbered at any point. A row therefore records what a
  session said on the day rather than pointing into the course as it stands now,
  and a number that no longer names anything is expected. The renderer ignores
  such a number — `ArchiDep.CourseSite.Progress.status/2` is a set lookup — and
  the admin console is what shows it, so that it is not silently dropped the
  next time the session is edited.

  ## Order

  The sessions are read in the order they were taught, which is `date` and then
  `created_at`: two sessions may carry the same date, and the one entered second
  is the one taught second. Only the **last** session depends on that order —
  `ArchiDep.CourseSite.Progress` unions the rest — which is what makes an order
  derived from the data rather than stored beside it safe.
  """

  use ArchiDep, :schema

  alias ArchiDep.Course.Types
  alias ArchiDep.CourseSite.Session

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          date: Date.t(),
          title: String.t(),
          done: [pos_integer()],
          due: [pos_integer()],
          next: [pos_integer()],
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @categories [:done, :due, :next]
  @max_title_length 100

  schema "course_sessions" do
    field(:date, :date)
    field(:title, :string)
    field(:done, {:array, :integer}, default: [])
    field(:due, {:array, :integer}, default: [])
    field(:next, {:array, :integer}, default: [])
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @doc """
  Every session of the course, in the order they were taught.
  """
  @spec list_course_sessions() :: [t()]
  def list_course_sessions,
    do: Repo.all(from(cs in __MODULE__, order_by: [asc: cs.date, asc: cs.created_at]))

  @doc """
  Fetches the session with the given identifier.
  """
  @spec fetch_course_session(UUID.t()) :: {:ok, t()} | {:error, :course_session_not_found}
  def fetch_course_session(id),
    do: __MODULE__ |> Repo.get(id) |> truthy_or(:course_session_not_found)

  @doc """
  What this session recorded, as the value the course material site is built
  from.
  """
  @spec to_session(t()) :: Session.t()
  def to_session(%__MODULE__{date: date, title: title, done: done, due: due, next: next}),
    do: Session.new(date, title, done, due, next)

  @spec new(Types.course_session_data(), DateTime.t()) :: Changeset.t(t())
  def new(data, now) do
    %__MODULE__{}
    |> cast(data, [:date, :title | @categories])
    |> change(id: UUID.generate(), version: 1, created_at: now, updated_at: now)
    |> validate()
  end

  @spec update(t(), Types.course_session_data(), DateTime.t()) :: Changeset.t(t())
  def update(course_session, data, now) do
    course_session
    |> cast(data, [:date, :title | @categories])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate()
  end

  @spec delete(t()) :: Changeset.t(t())
  def delete(course_session), do: change(course_session)

  defp validate(changeset) do
    changeset
    |> update_change(:title, &trim/1)
    |> validate_required([:date, :title])
    |> validate_length(:title, max: @max_title_length)
    |> validate_categories()
  end

  # Stored sorted and de-duplicated, so that two sessions recording the same
  # numbers in a different order are the same row, and so that the union the
  # progress is computed from cannot depend on how they were typed.
  defp validate_categories(changeset),
    do:
      Enum.reduce(@categories, changeset, fn category, acc ->
        acc
        |> validate_change(category, &validate_numbers/2)
        |> update_change(category, &(&1 |> Enum.uniq() |> Enum.sort()))
      end)

  defp validate_numbers(category, numbers) do
    if Enum.all?(numbers, &(&1 >= 1)) do
      []
    else
      [{category, "must contain only section or chapter numbers"}]
    end
  end
end
