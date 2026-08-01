defmodule ArchiDep.CourseSite.Build.NotFound do
  @moduledoc """
  What a static host shows for a path the build never wrote.

  ## One file, and it is at the mount point

  A host that offers this at all offers exactly one of them, at the root of what
  it publishes: GitHub Pages — where the backup copy of the site is served from,
  and the one host of a build that reads this file — answers every miss under
  the mount point with `<mount point>/404.html`, whichever edition the reader
  was after. So it is anchored where `ArchiDep.CourseSite.Urls` anchors a
  `{:root_file, _}` rather than where it anchors a `{:site_file, _}`: a copy
  under an edition prefix would be a page nothing ever asks for.

  ## Which is why it carries none of the site's chrome

  One file standing for every edition cannot show one edition's chapter list,
  and the chrome it would be wrapped in names one build's digested stylesheet —
  the wrong stylesheet for every build published after it. So the page loads
  nothing at all: what it shows is written into it, and the only link it offers
  is the home page of the build that wrote it. A page shown when nothing was
  found is the wrong place to depend on something else being found.

  ## Every build carries it, though only one reads it

  The main site never does: its reverse proxy answers a static miss from the
  dashboard application, which has a 404 page of its own. The backup copy is
  what needs this one, and every other build carries it because a build that
  differed here would be one more thing that is true of some builds.
  """

  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.CourseSite.Urls.UrlContext

  # The course is taught and written in English, and no build of it is anything
  # else.
  @lang "en"

  @title "Page not found"

  # A real file at a real URL, so it is crawled like any other page of the site
  # unless it says otherwise.
  @robots "noindex"

  @doc """
  The page, whole, for a build addressing itself the way this context says.
  """
  @spec html(UrlContext.t()) :: String.t()
  def html(%UrlContext{} = urls) do
    """
    <!doctype html>
    <html lang="#{@lang}">
    <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="robots" content="#{@robots}" />
    <title>#{escape(PageMetadata.title(@title))}</title>
    <style>
    :root { color-scheme: light dark }
    body { display: flex; align-items: center; justify-content: center;
      min-height: 100vh; margin: 0; background: #eceff4; color: #2e3440;
      font-family: system-ui, sans-serif; line-height: 1.5 }
    main { max-width: 40rem; padding: 2rem; text-align: center }
    h1 { margin: 0 0 1rem; font-size: 4rem; line-height: 1; letter-spacing: -1px }
    @media (prefers-color-scheme: dark) {
      body { background: #0f172a; color: #b8c4d9 }
    }
    </style>
    </head>
    <body>
    <main>
    <h1>404</h1>
    <p><strong>#{escape(@title)} :(</strong></p>
    <p>The requested page could not be found.</p>
    <p><a href="#{escape(Urls.resolve!(urls, :home))}">Back to the course</a></p>
    </main>
    </body>
    </html>
    """
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
