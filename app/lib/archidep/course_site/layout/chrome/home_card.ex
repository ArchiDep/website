defmodule ArchiDep.CourseSite.Layout.Chrome.HomeCard do
  @moduledoc """
  One of the three lists the home page opens with: what the course did last
  time, what is due after it, and what the next session covers.

  Each is the same thing drawn three times — a heading over a handful of lines
  of the course — so a card is which of the three it is and the lines it holds,
  and the words and the colours that go with each are the drawing's business
  ([`Chrome.Home`](`ArchiDep.CourseSite.Layout.Chrome.Home`)).

  **A card with nothing in it is not a card.** What has nothing to show is
  absent from the list rather than present and empty, for the same reason a link
  the build cannot offer is absent from
  [`Chrome.Assigns`](`ArchiDep.CourseSite.Layout.Chrome.Assigns`) `links`: what
  draws it asks one question instead of two. A course whose last session set no
  work shows two cards, and one that has not started shows none.
  """

  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry

  @enforce_keys [:kind, :entries]
  defstruct [:kind, :entries]

  @typedoc """
  Which of the three lists a card is: what the last session finished, what it
  set work on, and what the next one covers.
  """
  @type kind :: :previously | :due_next | :next_time

  @type t :: %__MODULE__{
          kind: kind(),
          entries: nonempty_list(MenuEntry.t())
        }
end
