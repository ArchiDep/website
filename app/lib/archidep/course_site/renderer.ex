defmodule ArchiDep.CourseSite.Renderer do
  @moduledoc """
  Turns one course source file into what the site serves for it.

  A document goes through two stages, the same two Jekyll uses: everything
  written in `{% %}` and `{{ }}` is expanded first, and what comes out is then
  converted from Markdown to HTML. The order is what lets a tag produce Markdown
  and have it converted like the rest of the page.

  Slides stop after the first stage. A deck is converted in the browser by
  reveal.js, so `render_slides/1` hands back Markdown; converting it here would
  produce a page where a deck was expected.

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

  alias ArchiDep.CourseSite.Renderer.Excerpt
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Source

  @excerpt_separator "excerpt_separator"

  @doc """
  Render a page: a chapter's subject or exercise, a cheatsheet, the home page.
  """
  @spec render_page(RenderContext.t()) ::
          {:ok, Page.t()} | {:error, nonempty_list(RenderError.t())}
  def render_page(%RenderContext{} = context) do
    with {:ok, markdown, liquid_errors} <- Liquid.render(context),
         {:ok, document} <- parse(markdown, context) do
      {excerpt, body} = Excerpt.split(document, excerpt_separator(context))
      {html, body_errors} = html(body, context)
      {excerpt_html, excerpt_errors} = excerpt_html(excerpt, context)

      result(
        %Page{html: html, excerpt_html: excerpt_html},
        liquid_errors ++ body_errors ++ excerpt_errors,
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
  """
  @spec render_slides(RenderContext.t()) ::
          {:ok, Slides.t()} | {:error, nonempty_list(RenderError.t())}
  def render_slides(%RenderContext{} = context) do
    case Liquid.render(context) do
      {:ok, markdown, errors} ->
        result(
          %Slides{markdown: Source.substitute(context.source, markdown)},
          errors,
          context
        )

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

  defp excerpt_html(nil, _context), do: {nil, []}
  defp excerpt_html(document, context), do: html(document, context)

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
