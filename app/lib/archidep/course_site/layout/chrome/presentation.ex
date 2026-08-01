defmodule ArchiDep.CourseSite.Layout.Chrome.Presentation do
  @moduledoc """
  The deck of a chapter, shown above the chapter itself.

  A chapter that is presented in class opens with the slides that were shown, so
  that somebody reading it afterwards meets them in the order they happened.
  They are shown in place rather than only linked, because a link asks the
  reader to decide whether the slides are worth opening before they have seen
  any of them.

  The two links beside the heading open the deck properly, with and without the
  notes written for whoever is presenting. Both open in a new tab: a deck takes
  over the whole window, and coming back from it should be closing a tab rather
  than losing your place in the chapter.

  None of this is printed. A deck is a sequence of screens and prints as the
  first one, and the chapter's own PDF is where a printed deck comes from.

  The heading is the layout's rather than the document's, so its identifier is
  named by `ArchiDep.CourseSite.Layout.Chrome.Assigns` and read from there:
  whatever lists the page's headings has to agree with it, and the two are drawn
  in different places.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # How `reveal.js` is asked for the deck as a page to scroll rather than as
  # slides to step through, and for the notes that go with it.
  @embedded_query "?view=scroll"
  @with_notes_query "?show-notes=true"

  attr :url, :string, required: true, doc: "where the chapter's deck is published"

  @doc """
  A chapter's deck, above the chapter.
  """
  @spec presentation(map()) :: Rendered.t()
  def presentation(assigns) do
    ~H"""
    <div class="not-prose print:hidden">
      <div class="mt-4 mb-2 flex justify-between items-end gap-x-2">
        <h2 id={Assigns.heading_id(:presentation)} class="text-4xl font-bold">Presentation</h2>
        <div class="flex items-center gap-2">
          <a
            href={@url <> with_notes_query()}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-x-2 opacity-75 hover:opacity-100 tooltip"
            data-tip="Open with speaker notes"
          >
            <Heroicons.document_text class="size-8" />
          </a>
          <a
            href={@url}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-x-2 opacity-75 hover:opacity-100 tooltip"
            data-tip="Open"
          >
            <Heroicons.presentation_chart_line class="size-8" />
          </a>
        </div>
      </div>

      <iframe
        class="w-full aspect-video dark:opacity-85"
        src={@url <> embedded_query()}
        title="Slides"
      ></iframe>
    </div>
    """
  end

  defp embedded_query, do: @embedded_query
  defp with_notes_query, do: @with_notes_query
end
