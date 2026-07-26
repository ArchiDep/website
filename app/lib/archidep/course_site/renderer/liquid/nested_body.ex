defmodule ArchiDep.CourseSite.Renderer.Liquid.NestedBody do
  @moduledoc """
  Read a block tag's body as Liquid, to be rendered when the tag renders.

  The bodies of this course's prose tags are not inert: notes and callouts
  contain links to other chapters, written as `{% link %}`. Capturing such a
  body verbatim would put the tag itself on the page as text, so the body is
  parsed like any other part of the template and rendered before it is handed to
  the Markdown renderer. `Solid`'s own `if` and `for` read their bodies exactly
  this way.

  Use `ArchiDep.CourseSite.Renderer.Liquid.RawBody` instead for a body that is
  code.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias Solid.ParserContext

  @doc """
  Parse the body up to the matching `{% end<tag> %}`.
  """
  @spec parse(ParserContext.t(), String.t()) ::
          {:ok, Solid.Parser.parse_tree(), ParserContext.t()}
          | {:error, String.t(), Solid.Lexer.loc()}
  def parse(%ParserContext{} = context, end_tag_name) do
    case Solid.Parser.parse_until(context, end_tag_name, "Expected #{end_tag_name}") do
      {:ok, body, _tag_name, _tokens, context} -> {:ok, body, context}
      {:error, reason, loc} -> {:error, reason, loc}
    end
  end

  @doc """
  Render a parsed body to the Markdown that goes to the Markdown renderer.
  """
  @spec render(Solid.Parser.parse_tree(), Solid.Context.t(), keyword()) ::
          {String.t(), Solid.Context.t()}
  def render(body, %Solid.Context{} = context, options) do
    {rendered, context} = Solid.render(body, context, options)
    {IO.iodata_to_binary(rendered), context}
  end

  @doc """
  Render a parsed body and convert it, which is what a tag wrapping prose in
  HTML wants: its body is a Markdown document of its own.
  """
  @spec to_html(Solid.Parser.parse_tree(), Solid.Context.t(), keyword()) ::
          {String.t(), Solid.Context.t()}
  def to_html(body, %Solid.Context{} = context, options) do
    {markdown, context} = render(body, context, options)
    {html, errors} = Markdown.to_html(markdown, Registers.fetch!(context))
    {html, Registers.report(context, errors)}
  end
end
