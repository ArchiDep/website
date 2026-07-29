defmodule ArchiDep.CourseSite.Session do
  @moduledoc """
  One session of the course: the day it was taught, what it was called, and what
  it recorded of the progress through the course.

  A session records three lists of numbers — what it finished, what it set work
  on, and what the next one covers — and section and chapter numbers share one
  space, since a session lists `100` beside `101`.

  The sessions are kept as the list they are rather than folded into
  `ArchiDep.CourseSite.Progress` on the way in, because the union that module
  builds cannot answer what the **last** session covered, which is what the
  course material's home page shows.
  """

  @enforce_keys [:date, :title, :done, :due, :next]
  defstruct [:date, :title, :done, :due, :next]

  @type t :: %__MODULE__{
          date: Date.t(),
          title: String.t(),
          done: [pos_integer()],
          due: [pos_integer()],
          next: [pos_integer()]
        }

  @doc """
  Build a session from the day it was taught, what it was called and the numbers
  it recorded.

      iex> Session.new(~D[2025-09-19], "CLI", [100, 101], [102], [])
      %Session{date: ~D[2025-09-19], title: "CLI", done: [100, 101], due: [102], next: []}
  """
  @spec new(Date.t(), String.t(), [pos_integer()], [pos_integer()], [pos_integer()]) :: t()
  def new(%Date{} = date, title, done, due, next)
      when is_binary(title) and is_list(done) and is_list(due) and is_list(next),
      do: %__MODULE__{date: date, title: title, done: done, due: due, next: next}

  @doc """
  The numbers a session recorded in one category.

      iex> Session.numbers(Session.new(~D[2025-09-19], "CLI", [100], [102], []), :done)
      [100]
  """
  @spec numbers(t(), :done | :due | :next) :: [pos_integer()]
  def numbers(%__MODULE__{done: done}, :done), do: done
  def numbers(%__MODULE__{due: due}, :due), do: due
  def numbers(%__MODULE__{next: next}, :next), do: next
end
