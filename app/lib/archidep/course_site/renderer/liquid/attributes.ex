defmodule ArchiDep.CourseSite.Renderer.Liquid.Attributes do
  @moduledoc """
  The `key: value` lists the course's block tags take — `{% cols columns: 3 %}`,
  `{% note type: tip %}`, `{% callout type: more, id: what-is-npm %}`.

  Jekyll's tags scan their markup with a regular expression, which makes the
  separator between two attributes a matter of taste: the content uses commas,
  spaces, quoted and unquoted values interchangeably. `Solid`'s lexer already
  produces the tokens, so all that is needed here is to read pairs off it and to
  accept every separator the content actually uses, rather than the one a tag
  author had in mind.

  Values keep the type the lexer gave them, so `columns: 3` is the number 3.
  """

  @doc """
  Read the attribute list out of the tokens of a tag, as
  `Solid.Lexer.tokenize_tag_end/1` produces them.

  `{% callout type: more, id: what-is-npm %}` gives `%{"type" => "more", "id" =>
  "what-is-npm"}`, and `{% cols columns: 3 %}` gives `%{"columns" => 3}`.
  """
  @spec parse(Solid.Lexer.tokens()) ::
          {:ok, %{String.t() => term()}} | {:error, String.t(), Solid.Lexer.loc()}
  def parse(tokens), do: collect(tokens, %{})

  defp collect([{:end, _loc}], attributes), do: {:ok, attributes}

  defp collect([{:comma, _loc} | rest], attributes), do: collect(rest, attributes)

  defp collect([{:identifier, _loc, key}, {:colon, _colon_loc} | rest], attributes) do
    case rest do
      [value_token | rest] ->
        case value(value_token) do
          {:ok, value} -> collect(rest, Map.put(attributes, key, value))
          :error -> {:error, "Unexpected attribute value", loc(value_token)}
        end

      [] ->
        {:error, "Missing value for attribute #{inspect(key)}", %{line: 1, column: 1}}
    end
  end

  defp collect([token | _rest], _attributes),
    do: {:error, "Expected a `key: value` attribute", loc(token)}

  defp collect([], _attributes), do: {:error, "Unterminated attributes", %{line: 1, column: 1}}

  defp value({:string, _loc, string, _quotes}), do: {:ok, string}
  defp value({:integer, _loc, integer}), do: {:ok, integer}
  defp value({:float, _loc, float}), do: {:ok, float}
  defp value({:identifier, _loc, identifier}), do: {:ok, identifier}
  defp value(_token), do: :error

  defp loc(token), do: elem(token, 1)
end
