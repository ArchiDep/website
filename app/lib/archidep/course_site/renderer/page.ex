defmodule ArchiDep.CourseSite.Renderer.Page do
  @moduledoc """
  A rendered page of the course material site.

  It comes in two pieces because the site shows a page in two places: its
  opening above the table of contents, and the rest of it below. A page with
  nothing to introduce — a cheatsheet, a page of a single paragraph — has no
  opening at all.
  """

  @enforce_keys [:html, :excerpt_html]
  defstruct [:html, :excerpt_html]

  @type t :: %__MODULE__{html: String.t(), excerpt_html: String.t() | nil}
end
