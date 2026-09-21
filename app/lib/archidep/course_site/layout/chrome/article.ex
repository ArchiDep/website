defmodule ArchiDep.CourseSite.Layout.Chrome.Article do
  @moduledoc """
  A page of the course and everything the site shows around the page itself: its
  title, its opening, its headings, where to download it, and where it is
  written.

  ## The opening is shown twice over, in two senses

  A page's opening is drawn above the list of its headings and the rest of it
  below, so that a reader meets what the page is about before deciding whether
  to jump into it. That is why `ArchiDep.CourseSite.Renderer.Page` hands over
  two pieces rather than one document: splitting here would mean parsing what
  was already parsed.

  ## The headings are drawn twice, and are the same list

  On a wide screen the headings sit beside the text; on a narrow one they fold
  above it; on paper they are a table of contents. All three are one list drawn
  by `ArchiDep.CourseSite.Layout.Chrome.Toc`, and the list opens with the
  headings *this* module draws — a chapter's presentation, an exercise's legend
  — because those are what a reader meets first.

  ## Wide is how much room the page has, not how wide the window is

  Whether the headings sit beside the text, and how large the text is, depends
  on the width of the column the page is drawn in rather than on the window's:
  from `lg` up the course menu takes a fixed part of the window, so a window
  wide enough by its own measure can still leave too little room. The sizes
  that decide it are named in `theme/src/theme.css`.

  The text's padding is set as `--content-pad` because what reaches out of the
  text into the padding — a code block, a callout — must know how far to go.

  ## What the aside offers

  A page offers itself as a PDF when one has been published for it, and always
  offers the source it was written from. The first is a question about the build
  rather than about the page, which is why an unpublished PDF leaves the link
  out instead of failing the build; the second is a question about the checkout,
  and a build made from a source tarball has no revision to point at.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Home
  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias ArchiDep.CourseSite.Layout.Chrome.Legend
  alias ArchiDep.CourseSite.Layout.Chrome.Presentation
  alias ArchiDep.CourseSite.Layout.Chrome.Toc
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # Where the top of the page is, which is what both "Back to top" links point
  # at. It is an element of its own rather than the page itself because a
  # fragment is what makes the jump land without a script.
  @top_id "top"

  attr :page, Assigns,
    required: true,
    doc: "everything this page is drawn from, its own content included"

  @doc """
  A page and what the site shows around it.
  """
  @spec article(map()) :: Rendered.t()
  def article(assigns) do
    ~H"""
    <div class="@container flex justify-center-safe gap-4">
      <div class="[--content-pad:--spacing(4)] @3xl:[--content-pad:--spacing(6)] @prose-xl:[--content-pad:--spacing(8)] p-(--content-pad) min-w-0 rounded md:rounded-lg lg:rounded-xl xl:rounded-2xl w-full bg-linear-to-br from-transparent to-zinc-200 dark:from-transparent dark:to-zinc-800/40 @3xl:w-auto">
        <main class={[
          "prose prose-lg @prose-xl:prose-xl @prose-2xl:prose-2xl @max-3xl:max-w-none",
          @page.page_class
        ]}>
          <.title page={@page} />

          <div class="my-4">{Phoenix.HTML.raw(@page.content.excerpt_html || "")}</div>

          <div
            :if={@page.toc != []}
            class="my-4 toc collapse screen:collapse-arrow print:collapse-open bg-neutral/25 dark:bg-neutral border-base-300 border @toc:hidden"
          >
            <input type="checkbox" />
            <div id="on-this-page-inline-title" class="collapse-title text-xl font-bold">
              <span class="print:hidden">On this page</span>
              <span class="hidden print:inline">Table of contents</span>
            </div>
            <nav class="toc collapse-content text-sm" aria-labelledby="on-this-page-inline-title">
              <Toc.toc entries={@page.toc} />
            </nav>
          </div>

          <div :if={@page.cloud_server} class="pt-2 sticky top-0 z-10">
            <div
              class="cloud-server-data not-prose @toc:hidden"
              data-mode={@page.cloud_server}
              data-layout="horizontal"
            >
            </div>
          </div>

          <.opening page={@page} />

          {Phoenix.HTML.raw(@page.content.html)}

          <div class="@toc:hidden w-full flex justify-center items-center">
            <a href={"##{top_id()}"} id="back-to-top-bottom" class="btn btn-ghost btn-sm">
              <Heroicons.arrow_up class="size-4" /> Back to top
            </a>
          </div>
        </main>
      </div>
      <aside class="hidden @toc:block w-64 @prose-2xl:w-xs shrink-0">
        <h2 id="on-this-page-title" class="text-xl font-bold">On this page</h2>
        <nav class="toc" aria-labelledby="on-this-page-title">
          <Toc.toc entries={@page.toc} />
        </nav>
        <div class="my-4 pl-4 flex items-center gap-4">
          <a
            :if={@page.links[:page_pdf]}
            href={@page.links[:page_pdf]}
            class="tooltip"
            data-tip={@page.pdf_tooltip}
            download
          >
            <Heroicons.document_arrow_down class="size-6 opacity-50 hover:opacity-100" />
          </a>
          <a
            :if={@page.links[:deck_pdf]}
            href={@page.links[:deck_pdf]}
            class="tooltip"
            data-tip="Slides PDF"
            download
          >
            <Heroicons.presentation_chart_line class="size-6 opacity-50 hover:opacity-100" />
          </a>
          <a
            :if={@page.links[:source]}
            href={@page.links[:source]}
            class="tooltip"
            data-tip="Source code"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Icons.github class="size-6 opacity-50 hover:opacity-100" />
          </a>
        </div>
        <div class="pt-2 sticky top-0">
          <div :if={@page.cloud_server} class="cloud-server-data" data-mode={@page.cloud_server}>
          </div>

          <a href={"##{top_id()}"} id="back-to-top-side" class="btn btn-ghost btn-sm">
            <Heroicons.arrow_up class="size-4" /> Back to top
          </a>
        </div>
      </aside>
    </div>
    """
  end

  @doc """
  Where the top of a page is, which is what its "Back to top" links point at.
  """
  @spec top_id :: String.t()
  def top_id, do: @top_id

  attr :page, Assigns, required: true

  # The home page introduces the course rather than being part of it, so it is
  # named by what the course *is* instead of by a line of front matter.
  defp title(%{page: %Assigns{kind: :home}} = assigns) do
    ~H"""
    <Home.title links={@page.links} badges?={@page.policy.badges?} />
    """
  end

  defp title(assigns) do
    ~H"""
    <h1 class="text-2xl @2xl:text-3xl @3xl:text-4xl @prose-xl:text-5xl !mb-0">
      {@page.title}
    </h1>
    """
  end

  attr :page, Assigns, required: true

  # What the site says about a page before the page says anything: a greeting on
  # the home page, the deck a chapter was presented with, the key to an
  # exercise's pictures. A cheatsheet is handed over bare.
  defp opening(%{page: %Assigns{kind: :home}} = assigns) do
    ~H"""
    <Home.welcome />
    <Home.cards cards={@page.cards} />
    """
  end

  defp opening(%{page: %Assigns{kind: :exercise}} = assigns) do
    ~H"""
    <Legend.legend graded?={@page.graded?} emoji={@page.legend_emoji} />
    """
  end

  defp opening(%{page: %Assigns{kind: :subject, links: %{deck: _url}}} = assigns) do
    ~H"""
    <Presentation.presentation url={@page.links[:deck]} />
    """
  end

  defp opening(assigns) do
    ~H"""
    """
  end
end
