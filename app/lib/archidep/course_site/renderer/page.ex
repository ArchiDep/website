defmodule ArchiDep.CourseSite.Renderer.Page do
  @moduledoc """
  A rendered page of the course material site.

  It comes in two pieces because the site shows a page in two places: its
  opening above the table of contents, and the rest of it below. A page with
  nothing to introduce — a cheatsheet, a page of a single paragraph — has no
  opening at all.

  The table of contents between them is the page's own headings, opening
  included, as `ArchiDep.CourseSite.Renderer.Toc` reads them off what was
  rendered. What the site shows around a page — the legend of an exercise, the
  presentation of a chapter with slides — is not in it: those headings belong to
  whatever lays the page out, and so do their entries.
  """

  alias ArchiDep.CourseSite.Renderer.Toc.Entry

  @enforce_keys [:html, :excerpt_html, :toc]
  defstruct [:html, :excerpt_html, :toc]

  @type t :: %__MODULE__{
          html: String.t(),
          excerpt_html: String.t() | nil,
          toc: [Entry.t()]
        }
end
