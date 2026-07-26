defmodule ArchiDep.CourseSite.Renderer do
  @moduledoc """
  Turns one course source file into what the site serves for it.

  A document goes through two stages, the same two Jekyll uses: everything
  written in `{% %}` and `{{ }}` is expanded first, and what comes out is then
  converted from Markdown to HTML. The order is what lets a tag produce Markdown
  and have it converted like the rest of the page.

  Slides stop after the first stage. A deck is converted in the browser by
  reveal.js, so `render_slides/1` hands back Markdown; converting it here would
  produce a page where a deck was expected. What a deck refers to is resolved
  all the same — a reference is resolved wherever it is written, and a deck's
  images and emoji would otherwise be the only ones the build published as the
  author typed them.

  Nothing in here reads a file, talks to a database or knows about Phoenix: a
  render is a function of a `ArchiDep.CourseSite.Renderer.RenderContext`, which
  is what lets the same code produce the site being taught, a copy of it hosted
  elsewhere, a frozen archive and the build that gets printed to PDF.

  ## Reporting rather than raising

  A document that refers to a chapter that does not exist, an image that is not
  there or a partial that was never given to the build produces a page **and** a
  list of what is wrong with it. Every problem of a document is collected, so
  that an author fixes a page in one pass rather than one problem per build.
  Only a document that does not parse produces nothing at all.
  """

  alias ArchiDep.CourseSite.Renderer.AssetReferences
  alias ArchiDep.CourseSite.Renderer.EmojiImages
  alias ArchiDep.CourseSite.Renderer.Excerpt
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Renderer.Toc

  @excerpt_separator "excerpt_separator"

  @doc """
  Render a page: a chapter's subject or exercise, a cheatsheet, the home page.
  """
  @spec render_page(RenderContext.t()) ::
          {:ok, Page.t()} | {:error, nonempty_list(RenderError.t())}
  def render_page(%RenderContext{} = context) do
    with {:ok, markdown, liquid_errors} <- Liquid.render(context),
         {:ok, document} <- parse(markdown, context) do
      {excerpt, body, separator_errors} = split(document, context)
      {html, body_errors} = html(body, context)
      {excerpt_html, excerpt_errors} = excerpt_html(excerpt, context)

      result(
        %Page{html: html, excerpt_html: excerpt_html, toc: toc(excerpt_html, html)},
        liquid_errors ++ separator_errors ++ body_errors ++ excerpt_errors,
        context
      )
    else
      {:error, errors} -> {:error, shift(errors, context)}
    end
  end

  @doc """
  Render a slide deck, which stays Markdown for reveal.js to convert.

  The document's link reference definitions are substituted into it rather than
  appended to it: reveal.js splits a deck into slides and converts each one on
  its own, so definitions sitting at the bottom would only ever serve the last
  slide.

  A deck goes through neither of the build's pass seams, having no document and
  no page, so the two rewrites it needs regardless of what a build asked for are
  called here: the files it shows are resolved to the names they are published
  under, and its emoji are drawn.
  """
  @spec render_slides(RenderContext.t()) ::
          {:ok, Slides.t()} | {:error, nonempty_list(RenderError.t())}
  def render_slides(%RenderContext{} = context) do
    case Liquid.render(context) do
      {:ok, markdown, liquid_errors} ->
        {deck, sweep_errors} =
          context.source
          |> Source.substitute(markdown)
          |> sweep(context)

        # A deck writing `relative_file_url` asks for a file the Liquid stage
        # resolves and the sweep then resolves again, so a file that is missing
        # is missing twice. It is one problem with the deck.
        result(%Slides{markdown: deck}, Enum.uniq(liquid_errors ++ sweep_errors), context)

      {:error, errors} ->
        {:error, shift(errors, context)}
    end
  end

  @doc """
  Parse the partials a build lets its documents include, so that rendering one
  is a lookup rather than a parse.
  """
  @spec compile_includes(%{String.t() => String.t()}) ::
          {:ok, %{String.t() => Solid.Template.t()}} | {:error, nonempty_list(RenderError.t())}
  def compile_includes(sources) when is_map(sources) do
    {includes, errors} =
      Enum.reduce(sources, {%{}, []}, fn {path, source}, {includes, errors} ->
        case Liquid.parse(source, Tags.default(), path) do
          {:ok, template} -> {Map.put(includes, path, template), errors}
          {:error, parse_errors} -> {includes, errors ++ parse_errors}
        end
      end)

    case errors do
      [] -> {:ok, includes}
      errors -> {:error, errors}
    end
  end

  # The files first and the emoji second: drawing an emoji writes an image of
  # its own, and it is an asset of the build rather than a file next to the
  # deck. Sweeping in this order means neither sweep ever sees what the other
  # wrote.
  defp sweep(markdown, context) do
    {with_files, file_errors} = AssetReferences.rewrite(markdown, :markdown, context)
    {drawn, emoji_errors} = EmojiImages.draw(with_files, :markdown, context)

    {drawn, file_errors ++ emoji_errors}
  end

  defp parse(markdown, context) do
    case Markdown.parse(markdown, context) do
      {:ok, document} -> {:ok, document}
      {:error, error} -> {:error, [error]}
    end
  end

  defp html(document, context) do
    {rendered, errors} = Markdown.render(document, context)
    {passed, pass_errors} = run_html_passes(rendered, context)
    {passed, errors ++ pass_errors}
  end

  # A page that declares a separator it never writes is cut where a page that
  # declares none is cut, so that the rest of its problems are reported in the
  # same pass as the omission.
  defp split(document, context) do
    separator = excerpt_separator(context)

    case Excerpt.split(document, separator) do
      {:ok, excerpt, body} ->
        {excerpt, body, []}

      {:missing_separator, excerpt, body} ->
        {excerpt, body,
         [RenderError.new({:missing_excerpt_separator, separator}, context.source_path)]}
    end
  end

  defp excerpt_html(nil, _context), do: {nil, []}
  defp excerpt_html(document, context), do: html(document, context)

  # The opening of a page is part of the page, so a heading in it is an entry of
  # the table of contents like any other.
  defp toc(nil, html), do: Toc.extract(html)
  defp toc(excerpt_html, html), do: Toc.extract(excerpt_html <> html)

  # The passes see a finished fragment of the page — the opening and the rest of
  # it alike, since both end up on the same page and must be treated the same.
  defp run_html_passes(html, context) do
    Enum.reduce(context.options.html_passes, {html, []}, fn pass, {passed, errors} ->
      {passed, pass_errors} = pass.run(passed, context)
      {passed, errors ++ pass_errors}
    end)
  end

  defp excerpt_separator(context) do
    case Map.get(RenderContext.page_variables(context), @excerpt_separator) do
      separator when is_binary(separator) -> separator
      _none -> nil
    end
  end

  defp result(rendered, [], _context), do: {:ok, rendered}
  defp result(_rendered, errors, context), do: {:error, shift(errors, context)}

  defp shift(errors, context),
    do: Enum.map(errors, &RenderError.shift(&1, context.source.body_line_offset))
end
