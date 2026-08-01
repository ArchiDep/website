defmodule ArchiDep.CourseSite.Layout.Chrome.MenuSection do
  @moduledoc """
  One heading of the course's navigation and the lines folded under it.

  A section of the navigation is a heading, a colour saying how far the course
  has got with it, whether it starts open, and the chapters beneath it. Like
  [`MenuEntry`](`ArchiDep.CourseSite.Layout.Chrome.MenuEntry`), it holds nothing
  the template would have to work out: the fold is already decided, because it
  follows from the same statuses the colours do rather than from anything the
  sidebar knows.
  """

  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias ArchiDep.CourseSite.Progress

  @enforce_keys [:title, :slug, :status, :open?, :entries]
  defstruct [:title, :slug, :status, :open?, :entries]

  @typedoc """
  A heading of the navigation: what it is called, the identifier its fold is
  toggled by, how far the course has got with it, whether it is folded open, and
  the chapters under it.
  """
  @type t :: %__MODULE__{
          title: String.t(),
          slug: String.t(),
          status: Progress.status(),
          open?: boolean(),
          entries: [MenuEntry.t()]
        }
end
