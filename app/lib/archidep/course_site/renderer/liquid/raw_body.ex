defmodule ArchiDep.CourseSite.Renderer.Liquid.RawBody do
  @moduledoc """
  Capture a block tag's body verbatim, without parsing any Liquid inside it.

  This is what a tag whose body is code or a diagram wants: a `{{` in a shell
  sample or a Jinja template is text, not the start of an expression, and
  reading it as one would fail the build over a code block that is perfectly
  correct.

  A tag whose body is prose wants the opposite —
  `ArchiDep.CourseSite.Renderer.Liquid.NestedBody` — because prose in this
  course does contain Liquid.

  It is `Solid.Tags.RawTag`'s own body scanner, generalised over the name of the
  closing tag, whitespace control included.
  """

  alias Solid.ParserContext

  @whitespaces [" ", "\f", "\r", "\t", "\v"]

  @doc """
  Read `context.rest` up to the matching `{% end<tag> %}`.
  """
  @spec parse(ParserContext.t(), String.t()) ::
          {:ok, String.t(), ParserContext.t()} | {:error, String.t(), Solid.Lexer.loc()}
  def parse(%ParserContext{} = context, end_tag_name) do
    case scan(context, end_tag_name, [], []) do
      {:ok, body, context} -> {:ok, IO.iodata_to_binary(body), context}
      {:error, reason, loc} -> {:error, reason, loc}
    end
  end

  defp scan(context, end_tag_name, buffer, trailing_whitespace) do
    case context.rest do
      <<"\n", rest::binary>> ->
        scan(
          %{context | rest: rest, line: context.line + 1, column: 1},
          end_tag_name,
          buffer,
          ["\n" | trailing_whitespace]
        )

      <<character::binary-size(1), rest::binary>> when character in @whitespaces ->
        scan(
          %{context | rest: rest, column: context.column + 1},
          end_tag_name,
          buffer,
          [character | trailing_whitespace]
        )

      <<"{%", rest::binary>> ->
        case Solid.Parser.maybe_tokenize_tag(end_tag_name, context) do
          {:tag, _tag_name, _tokens, context} ->
            {:ok, Enum.reverse(closing_buffer(buffer, trailing_whitespace, rest)), context}

          {:not_found, context} ->
            scan(
              %{context | rest: rest, column: context.column + 2},
              end_tag_name,
              ["{%" | trailing_whitespace ++ buffer],
              []
            )
        end

      "" ->
        {:error, "Tag not terminated, expected {% #{end_tag_name} %}",
         %{line: context.line, column: context.column}}

      <<character, rest::binary>> ->
        scan(
          %{context | rest: rest, column: context.column + 1},
          end_tag_name,
          [character | trailing_whitespace ++ buffer],
          []
        )
    end
  end

  # A closing tag written `{%- endx %}` asks for the whitespace before it to go
  # away; one written `{% endx %}` keeps it.
  defp closing_buffer(buffer, trailing_whitespace, rest) do
    if String.starts_with?(rest, "-"),
      do: buffer,
      else: trailing_whitespace ++ buffer
  end
end
