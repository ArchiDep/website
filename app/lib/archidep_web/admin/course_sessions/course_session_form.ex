defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionForm do
  @moduledoc """
  Course session form schema and changeset functions for recording a session of
  the course and correcting one already recorded. This schema only validates the
  basic structure and types of the fields. Business validations are handled in
  the course context.

  ## Why the three categories arrive as maps

  A number belongs to a category or it does not, which is a checkbox — and an
  unchecked checkbox sends nothing at all. Named `course_session[done][]`, the
  three categories would therefore be missing from the parameters as soon as
  their last box was cleared, `Ecto.Changeset.cast/3` would leave the stored
  list alone, and a category could be added to but never emptied. So each box is
  named for its own number and paired with a hidden `"false"`, as every other
  checkbox in this console is, and the map that arrives is folded back into a
  sorted list here.
  """

  use Ecto.Schema

  import ArchiDepWeb.Helpers.FormHelpers, only: [process_integer: 1]
  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Course.Types
  alias Ecto.Changeset

  @type t :: struct()

  @categories [:done, :due, :next]

  @primary_key false
  embedded_schema do
    field(:date, :date)
    field(:title, :string, default: "")
    field(:done, {:array, :integer}, default: [])
    field(:due, {:array, :integer}, default: [])
    field(:next, {:array, :integer}, default: [])
  end

  @doc """
  The form a session about to be recorded starts from: the day it is being
  recorded on, and nothing else. A session is recorded on the day it was taught
  far more often than not, and the date is the one field that cannot be left
  out.

  It is the data the form is cast onto rather than a parameter of the cast, so
  that clearing the field leaves the form incomplete instead of filling the day
  back in.
  """
  @spec initial_changeset(Date.t()) :: Changeset.t(Types.course_session_data())
  def initial_changeset(%Date{} = today), do: changeset(%__MODULE__{date: today}, %{})

  @spec create_changeset(map()) :: Changeset.t(Types.course_session_data())
  def create_changeset(params \\ %{}) when is_map(params),
    do: changeset(%__MODULE__{}, params)

  @spec update_changeset(CourseSession.t(), map()) :: Changeset.t(Types.course_session_data())
  def update_changeset(%CourseSession{} = course_session, params \\ %{}) when is_map(params),
    do:
      changeset(
        %__MODULE__{
          date: course_session.date,
          title: course_session.title,
          done: course_session.done,
          due: course_session.due,
          next: course_session.next
        },
        params
      )

  @spec to_course_session_data(t()) :: Types.course_session_data()
  def to_course_session_data(%__MODULE__{} = form), do: Map.from_struct(form)

  defp changeset(%__MODULE__{} = data, params) do
    %Changeset{} =
      data
      |> cast(Enum.reduce(@categories, params, &checked_numbers/2), [:date, :title | @categories])
      |> validate_required([:date, :title])
  end

  defp checked_numbers(category, params) do
    key = Atom.to_string(category)

    case Map.fetch(params, key) do
      {:ok, boxes} when is_map(boxes) ->
        Map.put(params, key, boxes |> Enum.flat_map(&checked_number/1) |> Enum.sort())

      _anything_else ->
        params
    end
  end

  defp checked_number({num, "true"}) do
    case process_integer(num) do
      {:ok, number} -> [number]
      :error -> []
    end
  end

  defp checked_number({_num, _unchecked}), do: []
end
