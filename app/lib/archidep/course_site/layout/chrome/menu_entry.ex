defmodule ArchiDep.CourseSite.Layout.Chrome.MenuEntry do
  @moduledoc """
  One line of the course's navigation, with nothing left to work out.

  The navigation shows a chapter and a cheatsheet as the same kind of thing — a
  picture, a name and a link — even though the two are different values with
  different fields, only one of which has a number or a deck. Flattening both
  into this is what lets the sidebar be a loop over a list rather than a
  template that knows which is which.

  The one place the two are genuinely not alike is progress. A chapter is taught
  on a date and so is done, due, next or still to come; a **cheatsheet is not
  part of that** — it is a reference the whole course points at, true from the
  first week to the last. So its `status` is `nil` rather than `:future`, which
  would be both a claim nobody made and a visibly wrong one: `:future` is what
  the navigation dims, and a cheatsheet is never dimmed.

  Everything else here is settled: the URL is resolved, the picture is drawn,
  and whether this is the page being laid out has been decided. A template that
  still had to work any of that out would be a template that could fail, and
  what draws the chrome cannot fail
  ([`Chrome.Assigns`](`ArchiDep.CourseSite.Layout.Chrome.Assigns`) says why).
  """

  alias ArchiDep.CourseSite.Progress

  @enforce_keys [:url, :title, :emoji_html, :deck_emoji_html, :status, :current?, :deck?]
  defstruct [:url, :title, :emoji_html, :deck_emoji_html, :status, :current?, :deck?]

  @typedoc """
  A line of the navigation: where it goes, what it is called, the picture it
  carries, the second picture announcing the deck it presents, how far the
  course has got with it if that means anything, whether it is the page being
  laid out, and whether it *is* a deck.

  A chapter with no deck to announce carries no second picture rather than a
  flag saying there is none, so what draws the line asks one question instead of
  two. A cheatsheet carries no status for the same reason.
  """
  @type t :: %__MODULE__{
          url: String.t(),
          title: String.t(),
          emoji_html: String.t(),
          deck_emoji_html: String.t() | nil,
          status: Progress.status() | nil,
          current?: boolean(),
          deck?: boolean()
        }
end
