defmodule ArchiDep.CourseSite.Progress do
  @moduledoc """
  How far the course has got: what has been done, what is due, and what comes
  next.

  This is deliberately **not** part of `ArchiDep.CourseSite.Structure`. What the
  course is, is a function of the content directory; how far it has got changes
  on every teaching session and is recorded in a source of its own. Keeping the
  two apart is what lets the structure be compiled while a status stays a value
  passed in at render time.

  ## What a session says

  Each session of the course records what it covered as three lists of numbers —
  `done`, `due` and `next` — and the whole is the **union** of every session's,
  with the later categories subtracted from the earlier ones: something listed
  as due after having been done is done, and something listed as next after
  either is neither. So a number belongs to at most one category, and a number
  no session ever listed is still to come.

  ## Sections and chapters are numbered in the same space

  A section's number (100, 200, …) is recorded in the very same lists as a
  chapter's (101, 402, …) — the course's first session lists `100` beside its
  chapters. So `status/2` is one lookup rather than one per kind, and it is what
  colours a section heading as well as an entry under it.

  ## The union, and the last session

  Everything above is the union. `last_recorded/3` is the one question it cannot
  answer: what the course did *last time*, which is what the home page shows and
  which the union has folded into everything that came before it. That is why
  the sessions are kept as the list they are — see
  `ArchiDep.CourseSite.Session`.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section

  @enforce_keys [:done, :due, :next, :last]
  defstruct [:done, :due, :next, :last]

  @typedoc """
  What has become of one section or chapter of the course:

  - `:done` — covered.
  - `:due` — covered, with work to hand in.
  - `:next` — what the coming session covers.
  - `:future` — still to come.
  """
  @type status :: :done | :due | :next | :future

  @typedoc """
  Whether a page shows the answers it holds. Declared here rather than borrowed
  from the renderer that is told it, so that how far the course has got does not
  depend on what renders it.
  """
  @type solutions :: :revealed | :hidden

  @typedoc """
  How far the course has got: what has been done, what is due and what comes
  next, and the last session that was taught — `nil` for a course nobody has
  taught yet.
  """
  @type t :: %__MODULE__{
          done: MapSet.t(pos_integer()),
          due: MapSet.t(pos_integer()),
          next: MapSet.t(pos_integer()),
          last: Session.t() | nil
        }

  @doc """
  Work out how far the course has got from what each of its sessions recorded,
  in the order they were taught.
  """
  @spec new([Session.t()]) :: t()
  def new(sessions) when is_list(sessions) do
    done = numbers(sessions, :done)
    due = MapSet.difference(numbers(sessions, :due), done)

    next =
      sessions
      |> numbers(:next)
      |> MapSet.difference(done)
      |> MapSet.difference(due)

    %__MODULE__{done: done, due: due, next: next, last: List.last(sessions)}
  end

  @doc """
  What has become of the section or chapter with the given number.
  """
  @spec status(t(), pos_integer()) :: status()
  def status(%__MODULE__{done: done, due: due, next: next}, num) when is_integer(num) do
    cond do
      MapSet.member?(done, num) -> :done
      MapSet.member?(due, num) -> :due
      MapSet.member?(next, num) -> :next
      true -> :future
    end
  end

  @doc """
  What has become of every section and every chapter of the course, ready to be
  handed to whatever lists it.
  """
  @spec statuses(t(), Structure.t()) :: %{pos_integer() => status()}
  def statuses(%__MODULE__{} = progress, %Structure{sections: sections}),
    do:
      sections
      |> Enum.flat_map(fn %Section{chapters: chapters} = section ->
        [Section.num(section) | Enum.map(chapters, &Chapter.num/1)]
      end)
      |> Map.new(&{&1, status(progress, &1)})

  @doc """
  The chapters the course's last session recorded in one category, in the order
  the course lists them.

  A section's number is recorded in the same lists as a chapter's, so a number
  naming one is simply not a chapter and drops out: what comes back is what the
  home page can link to.

  `:due` is work to hand in, and a chapter that is only a deck has none — a
  presentation is watched, not handed in — so those are left out of that
  category alone. Every chapter is a candidate for the other two.

  ## A session that recorded nothing recorded nothing

  The lists are the last session's and no earlier one's: a session that ends the
  course by setting no work leaves nothing due, rather than leaving the
  previous session's work due for ever. A category a session left out and one it
  wrote empty say the same thing here, which is what
  `ArchiDep.CourseSite.Build.ProgressFile` already reads them as.
  """
  @spec last_recorded(t(), Structure.t(), :done | :due | :next) :: [Chapter.t()]
  def last_recorded(%__MODULE__{last: last}, %Structure{} = structure, category)
      when category in [:done, :due, :next] do
    numbers = recorded(last, category)

    structure
    |> Structure.chapters()
    |> Enum.filter(&(MapSet.member?(numbers, Chapter.num(&1)) and listed?(&1, category)))
  end

  @doc """
  Whether the chapter with the given number shows the answers to its exercise,
  which it does once the course has covered it.

  A chapter that is merely due is one the course has covered *and* set work on,
  so its answers stay withheld until that work is in. The threshold is named
  here rather than at each build that applies it, so that two builds of the same
  course cannot disagree about what a student may read.
  """
  @spec solutions_revealed?(t(), pos_integer()) :: boolean()
  def solutions_revealed?(%__MODULE__{} = progress, num) when is_integer(num),
    do: status(progress, num) == :done

  @doc """
  Whether a page shows the answers it holds, as the renderer is told it.

  Only a chapter has a status to consult, and only a chapter may hold an answer
  at all — the renderer refuses a solution written on the home page or in a
  cheatsheet — so every other page is handed `:revealed` and the question never
  arises. Applying `solutions_revealed?/2` is what a build does with the
  threshold above, and it is here rather than in each build so that two of them
  cannot disagree.
  """
  @spec solutions(t(), PageRef.t()) :: solutions()
  def solutions(%__MODULE__{} = progress, {:document, %DocumentRef{num: num}}),
    do: if(solutions_revealed?(progress, num), do: :revealed, else: :hidden)

  def solutions(%__MODULE__{}, _page), do: :revealed

  @doc """
  Whether a section is shown unfolded, which it is when it is what the coming
  session covers or when it holds a chapter the course is currently working
  through.

  This is a rule over what `statuses/2` produces rather than over the record
  itself, because whatever lists the course is handed those statuses and nothing
  else: the fold of a section has to follow from the same data its colours do.
  """
  @spec section_open?(%{pos_integer() => status()}, Section.t()) :: boolean()
  def section_open?(statuses, %Section{chapters: chapters} = section) when is_map(statuses),
    do:
      status_of(statuses, Section.num(section)) == :next or
        Enum.any?(chapters, &(status_of(statuses, Chapter.num(&1)) not in [:done, :future]))

  defp status_of(statuses, num), do: Map.get(statuses, num, :future)

  defp recorded(nil, _category), do: MapSet.new()

  defp recorded(%Session{} = session, category),
    do: session |> Session.numbers(category) |> MapSet.new()

  defp listed?(%Chapter{page: %DocumentRef{type: :slides}}, :due), do: false
  defp listed?(%Chapter{}, _category), do: true

  defp numbers(sessions, category),
    do: sessions |> Enum.flat_map(&Session.numbers(&1, category)) |> MapSet.new()
end
