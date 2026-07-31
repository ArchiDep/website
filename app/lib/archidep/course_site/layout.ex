defmodule ArchiDep.CourseSite.Layout do
  @moduledoc """
  What the site shows around a rendered document.

  `ArchiDep.CourseSite.Renderer` produces a page's own prose and stops there, so
  something has to put a `<head>` on it, a header above it, the course's
  navigation beside it and a footer below. That is a layout, and it is a seam
  rather than a function of the build because a build wants a different one in
  different circumstances — the site's own chrome, and a deliberately bare
  wrapper for a build whose chrome is not the point.

  ## One callback, not one per kind of page

  The site has several layouts — a subject presents its deck, an exercise prints
  its legend, a cheatsheet is bare, a deck is a `reveal.js` document rather than
  a page at all — but choosing between them is the **layout's** business, not
  the build's. A build that picked would have to learn that table, and every
  layout added to it would change the build's own shape. So there is one
  callback, and an implementation pattern-matches on what it is given:

      def document(%LayoutContext{content: %Slides{}} = context), do: …
      def document(%LayoutContext{entry: %Chapter{graded?: true}} = context), do: …

  ## Reporting rather than raising

  A layout resolves references of its own — the stylesheets it loads, the PDF a
  page offers, the icon in its footer — and one that does not resolve is a fact
  about the build rather than a programmer error, exactly as it is [for a
  document](`ArchiDep.CourseSite.Renderer`). So a layout returns its errors and
  the build collects them across every page, rather than the first one stopping
  the build.

  Not every unresolved reference is an error, and the difference is the layout's
  to know: a page whose PDF has not been published yet leaves the download link
  out, where a missing stylesheet is a build that would publish pages nobody can
  read.
  """

  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Urls

  @doc """
  Wrap one rendered document in what the site shows around it.
  """
  @callback document(LayoutContext.t()) ::
              {:ok, String.t()} | {:error, nonempty_list(Urls.error())}
end
