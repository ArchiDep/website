defmodule ArchiDep.CourseSite.Layout.Chrome.Document do
  @moduledoc """
  The whole of a page as a browser receives it: what it says about itself, what
  it loads, and the bar and navigation around what it shows.

  ## Two things the `<head>` says to a script rather than to a browser

  `course/src/assets/course.ts` runs on every page and has to know two things
  the page cannot ask anybody at runtime: where the search index of this build
  is, and whether this build is the live site, so that it does not report a
  reader of an archived edition as a visitor to the current one. Both are
  written as data attributes, because a static file has nowhere else to put
  them.

  The index is named by its whole URL rather than by a file name for the script
  to join onto the mount point. That is not a convenience: its name carries the
  identifier of the build that produced it, which no script can work out, and it
  is what stops a freshly built page from searching the previous build's index.
  It also leaves the script with no URL of its own to assemble, which is the
  point of `ArchiDep.CourseSite.Urls`.

  ## What the script does before anything is drawn

  The one inline script on the page reads a preference kept in the browser and
  puts an empty element at the top of the body when it is set. It runs where it
  is written rather than with the rest of the scripts because what it decides is
  visible in the first paint: doing it later would show the page one way and
  then change it.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Article
  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Banner
  alias ArchiDep.CourseSite.Layout.Chrome.Header
  alias ArchiDep.CourseSite.Layout.Chrome.Sidebar
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # The course is taught and written in English, and no build of it is anything
  # else.
  @lang "en"

  # Where the fonts come from, announced early so the browser can open the
  # connections while it is still reading the rest of the head.
  @fonts_url "https://fonts.googleapis.com"
  @fonts_static_url "https://fonts.gstatic.com"

  # What names the drawer's checkbox, which is what the header's button and the
  # sidebar's own close button both toggle. It is written here because the
  # element it names is written here.
  @drawer_id "sidebar"

  # What names the pictures the search dialog draws with. The dialog is built by
  # a script out of markup of its own, so the page cannot draw its icons where
  # they go — it leaves them here, hidden, for the script to take. The dashboard
  # writes the same element under the same name, being the other page that runs
  # the dialog.
  @search_emoji_id "search-emoji"

  attr :page, Assigns,
    required: true,
    doc: "everything this page is drawn from, its own content included"

  @doc """
  A page of the course, whole.
  """
  @spec document(map()) :: Rendered.t()
  def document(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang={lang()}>
      <head
        data-search-data-url={@page.links[:search_data]}
        data-archidep-standalone={to_string(@page.standalone?)}
      >
        <meta charset="utf-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        {Phoenix.HTML.raw(@page.metadata_html)}
        <link rel="preconnect" href={fonts_url()} />
        <link rel="preconnect" href={fonts_static_url()} crossorigin />
        <link rel="stylesheet" href={@page.links[:theme_css]} />
        <link rel="icon" type="image/png" sizes="16x16" href={@page.links[:favicon_16]} />
        <link rel="icon" type="image/png" sizes="32x32" href={@page.links[:favicon_32]} />
        <link rel="icon" type="image/png" sizes="48x48" href={@page.links[:favicon_48]} />
        <link rel="icon" type="image/png" sizes="96x96" href={@page.links[:favicon_96]} />
        <link rel="icon" type="image/png" sizes="192x192" href={@page.links[:favicon_192]} />
        <link rel="apple-touch-icon" sizes="180x180" href={@page.links[:favicon_180]} />
        <link rel="shortcut icon" href={@page.links[:favicon]} />
        <script src={@page.links[:course_js]} defer>
        </script>
      </head>

      <body class="group/body">
        <div id={Article.top_id()} class="top-0 h-0"></div>

        <script type="text/javascript">
          if (localStorage.getItem('archidep.alwaysTellMeMore')) {
            const alwaysTellMeMore = document.createElement('div');
            alwaysTellMeMore.id = 'always-tell-me-more';
            alwaysTellMeMore.classList.add('hidden');
            document.body.prepend(alwaysTellMeMore);
          }
        </script>

        <div id={search_emoji_id()} hidden>
          <span :for={{name, image} <- @page.search_emoji} data-emoji={name}>
            {Phoenix.HTML.raw(image)}
          </span>
        </div>

        <Header.header links={@page.links} policy={@page.policy} site={@page.site} />

        <Banner.banner
          :if={@page.banner}
          kind={@page.banner}
          url={@page.links[:banner]}
          years={@page.site.years}
        />

        <div class="drawer lg:drawer-open">
          <input id={drawer_id()} type="checkbox" class="drawer-toggle" />
          <div class="drawer-content">
            <div class="md:p-4">
              <Article.article page={@page} />
            </div>
          </div>
          <div class="drawer-side z-20">
            <label for={drawer_id()} aria-label="close sidebar" class="drawer-overlay"></label>
            <Sidebar.sidebar
              sections={@page.sections}
              cheatsheets={@page.cheatsheets}
              links={@page.links}
              policy={@page.policy}
              home?={@page.kind == :home}
              version={@page.site.version}
              commit={@page.commit}
            />
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp lang, do: @lang
  defp fonts_url, do: @fonts_url
  defp fonts_static_url, do: @fonts_static_url
  defp drawer_id, do: @drawer_id
  defp search_emoji_id, do: @search_emoji_id
end
