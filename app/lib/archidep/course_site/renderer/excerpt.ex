defmodule ArchiDep.CourseSite.Renderer.Excerpt do
  @moduledoc """
  Where a page stops introducing itself and starts being itself.

  The site shows a page's opening above its table of contents and the rest of it
  below, so a page is really two fragments. Jekyll produces them by rendering
  the opening twice and then deleting one copy from the other by string match,
  which silently fails as soon as anything in the opening renders differently
  the second time. Splitting the parsed document instead cannot fail that way,
  and a separator written inside a code block is a code block rather than a
  place to cut.

  A document says where to cut with an `excerpt_separator` in its front matter,
  which every document that sets one writes as `<!-- more -->`. A document that
  sets none is cut after its first block, which is what Jekyll does by default.

  Declaring a separator and never writing it is neither of those: it is an
  omission, reported as `:missing_separator` for the renderer to turn into an
  error. The document is still cut after its first block so that the rest of its
  problems are found in the same pass. Jekyll instead makes the whole page the
  opening, which is visibly not what the author meant.
  """

  @doc """
  Split a parsed document into its opening and the rest of it.

  The opening is `nil` when there is nothing to cut, which is the case for a
  document of a single block.

      iex> {:ok, document} = MDEx.parse_document("Opening.\\n\\n<!-- more -->\\n\\nRest.\\n")
      iex> {:ok, excerpt, body} = Excerpt.split(document, "<!-- more -->")
      iex> {Enum.count(excerpt.nodes), Enum.count(body.nodes)}
      {1, 1}

      iex> {:ok, document} = MDEx.parse_document("Opening.\\n\\nRest.\\n")
      iex> {result, _excerpt, _body} = Excerpt.split(document, "<!-- more -->")
      iex> result
      :missing_separator
  """
  @spec split(MDEx.Document.t(), String.t() | nil) ::
          {:ok | :missing_separator, MDEx.Document.t() | nil, MDEx.Document.t()}
  def split(%MDEx.Document{nodes: nodes} = document, separator) do
    {result, excerpt, body} = split_nodes(nodes, separator)
    {result, opening(document, excerpt), %MDEx.Document{document | nodes: body}}
  end

  defp opening(_document, []), do: nil
  defp opening(%MDEx.Document{} = document, nodes), do: %MDEx.Document{document | nodes: nodes}

  defp split_nodes(nodes, separator) when is_binary(separator) do
    case Enum.split_while(nodes, &(not separator?(&1, separator))) do
      {_nodes, []} ->
        {excerpt, body} = default_split(nodes)
        {:missing_separator, excerpt, body}

      {excerpt, [_separator | body]} ->
        {:ok, excerpt, body}
    end
  end

  defp split_nodes(nodes, nil) do
    {excerpt, body} = default_split(nodes)
    {:ok, excerpt, body}
  end

  defp default_split([]), do: {[], []}
  defp default_split([only]), do: {[], [only]}
  defp default_split([first | rest]), do: {[first], rest}

  defp separator?(%MDEx.HtmlBlock{literal: literal}, separator),
    do: String.trim(literal) == String.trim(separator)

  defp separator?(_node, _separator), do: false
end
