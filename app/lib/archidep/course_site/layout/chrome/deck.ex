defmodule ArchiDep.CourseSite.Layout.Chrome.Deck do
  @moduledoc """
  A chapter's slides, as the document `reveal.js` turns into a presentation.

  This is not a page of the site with different chrome around it. A deck has no
  navigation, no header and no drawer, because it is shown on a projector rather
  than read in a browser tab beside other tabs: everything that is a way of
  getting somewhere else would be a thing to click by accident while presenting.
  What it carries instead is a corner saying which course, which build, and
  where the slides are written — and, in a build that is not the current site,
  the one link that corner does hold
  (`ArchiDep.CourseSite.Layout.Chrome.Banner`): a reader who has landed on a
  deck of a past edition has no other way of being told so.

  ## The deck stays Markdown

  What is written into the page is the deck's Markdown, not HTML: `reveal.js`
  reads it out of a `<textarea>`, splits it into slides and converts each one
  itself. Splitting it here would mean deciding where the slides are, which is
  the one thing `reveal.js` is being used for.

  The content of a `textarea` is RCDATA, so the deck goes in exactly as it
  stands: `<` starts no tag there, and a character reference is decoded before
  `reveal.js` sees it. The single exception is `</textarea`, which ends the
  element wherever it appears, so that alone is escaped — and it decodes back to
  itself.

  ## It is always light

  The body fixes the light theme rather than following the reader's. A deck is
  shown on somebody else's projector, and what that projector does with a dark
  theme is not something the slides can find out in time.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Banner
  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  @deck_close ~r{</textarea}i
  @deck_close_escaped "&lt;/textarea"

  @lang "en"
  @fonts_url "https://fonts.googleapis.com"
  @fonts_static_url "https://fonts.gstatic.com"
  @heig_url "https://heig-vd.ch/"
  @site_url "https://archidep.ch"

  attr :page, Assigns,
    required: true,
    doc: "everything this deck is drawn from, its own slides included"

  @doc """
  A chapter's deck, whole.
  """
  @spec deck(map()) :: Rendered.t()
  def deck(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang={lang()}>
      <head>
        <meta charset="utf-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        {Phoenix.HTML.raw(@page.metadata_html)}
        <link rel="preconnect" href={fonts_url()} />
        <link rel="preconnect" href={fonts_static_url()} crossorigin />
        <link rel="stylesheet" href={@page.links[:slides_css]} />
        <link rel="stylesheet" href={@page.links[:theme_slides_css]} />
        <script defer src={@page.links[:slides_mermaid_js]}>
        </script>
      </head>
      <body data-theme="light">
        <div class="reveal">
          <div class="slides">
            <section data-markdown>
              <textarea data-template>{Phoenix.HTML.raw(escape(@page.content.markdown))}</textarea>
            </section>
          </div>
        </div>

        <script src={@page.links[:slides_js]}>
        </script>

        <div id="meta" class="absolute bottom-4 left-4 z-10 flex items-end gap-2 font-meta">
          <a id="heig-vd-logo" href={heig_url()} target="_blank" rel="noopener noreferrer">
            <img src={@page.links[:heig_logo]} alt="HEIG-VD logo" width="40" height="40" />
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

          <a
            :if={@page.links[:page_pdf]}
            id="download-pdf"
            href={@page.links[:page_pdf]}
            class="print:hidden tooltip"
            data-tip="Download PDF"
            download
          >
            <Heroicons.document_arrow_down class="size-6 opacity-50 hover:opacity-100" />
          </a>

          <Banner.corner :if={@page.banner} kind={@page.banner} url={@page.links[:banner]} />
        </div>

        <div
          id="footer"
          class="tooltip absolute bottom-4 left-1/4 right-1/4 z-10 text-center font-meta text-sm opacity-25 hover:opacity-100"
        >
          <div class="tooltip-content">
            <ul class="list-none m-0 p-0 flex flex-col gap-1">
              <li>Architecture &amp; Deployment {@page.site.years}</li>
              <li :if={@page.site.git_branch} class="text-xs">
                v{@page.site.version} on branch {@page.site.git_branch}
              </li>
              <li :if={@page.site.git_branch == nil} class="text-xs">v{@page.site.version}</li>
              <li :if={@page.site.git_revision} class="text-xs">
                Rev: {@page.site.git_revision}
              </li>
            </ul>
          </div>
          <a href={site_url()} class="!no-underline hover:!underline">
            ArchiDep {@page.site.years_short} {@page.commit}
          </a>
        </div>
      </body>
    </html>
    """
  end

  defp escape(markdown), do: Regex.replace(@deck_close, markdown, @deck_close_escaped)

  defp lang, do: @lang
  defp fonts_url, do: @fonts_url
  defp fonts_static_url, do: @fonts_static_url
  defp heig_url, do: @heig_url
  defp site_url, do: @site_url
end
