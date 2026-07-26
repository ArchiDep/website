defmodule ArchiDep.CourseSite.Renderer.Toc.Entry do
  @moduledoc """
  One heading of a page, as the "On this page" navigation shows it.

  The label is the heading's own inline HTML rather than its text, because a
  heading is written with the same emphasis, inline code and emoji as the rest
  of the page and the navigation shows what the heading shows.

  The entries under it are the headings it introduces: the ones that follow it
  and are deeper than it. The level is kept alongside them because the theme
  sizes an entry by the level of its heading (`toc-h1` through `toc-h6`), which
  the nesting alone does not say once a page skips one.
  """

  @enforce_keys [:id, :level, :label_html]
  defstruct [:id, :level, :label_html, entries: []]

  @type t :: %__MODULE__{
          id: String.t(),
          level: 1..6,
          label_html: String.t(),
          entries: [t()]
        }
end
