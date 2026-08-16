defmodule ArchiDep.CourseSite.Renderer.Liquid.RawMarkup do
  @moduledoc """
  Consume a tag's markup verbatim, up to the `%}` that closes it.

  `Solid`'s lexer refuses the unquoted paths the course writes — `{% link
  _course/101-command-line/subject.md %}`, `{% include icons/photo.html %}` —
  because a bare `/` is not something a Liquid expression may contain. So these
  two tags do not tokenize their markup at all: they read the text and interpret
  it themselves, which is what lets a document go on naming a path the way it
  reads.

  A tag whose markup *is* a Liquid expression should use
  `Solid.Lexer.tokenize_tag_end/1` instead.
  """

  alias Solid.ParserContext

  @doc """
  Read `context.rest` up to the end of the tag, returning the markup with its
  surrounding whitespace removed.
  """
  @spec parse(ParserContext.t()) ::
          {:ok, String.t(), ParserContext.t()} | {:error, String.t(), Solid.Lexer.loc()}
  def parse(%ParserContext{} = context), do: scan(context, [])

  defp scan(context, buffer) do
    case context.rest do
      <<"-%}", rest::binary>> ->
        {:ok, markup(buffer), %{context | rest: rest, column: context.column + 3}}

      <<"%}", rest::binary>> ->
        {:ok, markup(buffer), %{context | rest: rest, column: context.column + 2}}

      <<"\n", rest::binary>> ->
        scan(%{context | rest: rest, line: context.line + 1, column: 1}, ["\n" | buffer])

      "" ->
        {:error, "Tag not terminated, expected %}", %{line: context.line, column: context.column}}

      <<character::binary-size(1), rest::binary>> ->
        scan(%{context | rest: rest, column: context.column + 1}, [character | buffer])
    end
  end

  defp markup(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
    |> String.trim()
  end
end
