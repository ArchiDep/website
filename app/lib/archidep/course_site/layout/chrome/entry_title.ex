defmodule ArchiDep.CourseSite.Layout.Chrome.EntryTitle do
  @moduledoc """
  What one chapter or cheatsheet is called, with the picture saying what it is.

  It is drawn in two places — every line of the [navigation of the
  course](`ArchiDep.CourseSite.Layout.Chrome.Sidebar`) and every line of the
  [home page's cards](`ArchiDep.CourseSite.Layout.Chrome.Home`) — and the two
  are read as one thing: the same chapter, named the same way, wherever it is
  listed. So it is one component rather than the same span written twice.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  attr :entry, MenuEntry, required: true, doc: "the line of the course to name"

  @doc """
  The name of a chapter or a cheatsheet, after the picture of what it is.
  """
  @spec entry_title(map()) :: Rendered.t()
  def entry_title(assigns) do
    ~H"""
    <span class="flex items-center gap-x-2">
      <span class="size-4">{Phoenix.HTML.raw(@entry.emoji_html)}</span>
      <span>{@entry.title}</span>
    </span>
    """
  end
end
