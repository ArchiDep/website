defmodule ArchiDep.CourseSite.Layout.Minimal do
  @moduledoc """
  The least a rendered document can be wrapped in and still be a document a
  browser will show.

  It is what a build uses when the chrome is not what is being checked: the
  document, its table of contents, and a `<head>` saying what the page is. It
  loads no stylesheet and no script deliberately — a layout that half-ported the
  site's own `<head>` would be the site's chrome, done badly, and the point of
  this one is to have nothing to be wrong about.

  A deck is not a page and is not laid out like one: it is handed to the browser
  as the text of a `<textarea>`, which `reveal.js` reads, splits into slides and
  converts. So what is around it is that element and its wrapper, not a
  document's chrome.
  """

  @behaviour ArchiDep.CourseSite.Layout

  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry

  # The content of a `textarea` is RCDATA, so a deck is written into one exactly
  # as it stands: `<` starts no tag there and a character reference is decoded
  # before `reveal.js` reads it, which is why the markup and the entities a deck
  # writes arrive intact. The one sequence that does not is `</textarea`, which
  # ends the element wherever it appears — so that alone is escaped, and it
  # decodes back to itself.
  @deck_close ~r{</textarea}i
  @deck_close_escaped "&lt;/textarea"

  @impl ArchiDep.CourseSite.Layout
  def document(%LayoutContext{content: %Slides{markdown: markdown}} = context) do
    {:ok,
     """
     <!doctype html>
     <html lang="en">
     <head>
     <meta charset="utf-8" />
     <meta name="viewport" content="width=device-width, initial-scale=1" />
     #{PageMetadata.to_html(context.metadata)}
     </head>
     <body>
     <div class="reveal"><div class="slides"><section data-markdown><textarea data-template>
     #{escape_deck(markdown)}
     </textarea></section></div></div>
     </body>
     </html>
     """}
  end

  def document(%LayoutContext{content: %Page{} = page} = context) do
    {:ok,
     """
     <!doctype html>
     <html lang="en">
     <head>
     <meta charset="utf-8" />
     <meta name="viewport" content="width=device-width, initial-scale=1" />
     #{PageMetadata.to_html(context.metadata)}
     </head>
     <body>
     #{opening(page)}#{toc(page)}<main>
     #{page.html}
     </main>
     </body>
     </html>
     """}
  end

  defp opening(%Page{excerpt_html: nil}), do: ""
  defp opening(%Page{excerpt_html: html}), do: "<header>\n#{html}\n</header>\n"

  defp toc(%Page{toc: []}), do: ""
  defp toc(%Page{toc: entries}), do: "<nav>\n#{list(entries)}\n</nav>\n"

  defp list(entries), do: "<ul>#{Enum.map_join(entries, &item/1)}</ul>"

  defp item(%Entry{id: id, label_html: label, entries: []}),
    do: ~s(<li><a href="##{id}">#{label}</a></li>)

  defp item(%Entry{id: id, label_html: label, entries: entries}),
    do: ~s(<li><a href="##{id}">#{label}</a>#{list(entries)}</li>)

  defp escape_deck(markdown), do: Regex.replace(@deck_close, markdown, @deck_close_escaped)
end
