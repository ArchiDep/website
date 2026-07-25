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
  does not — or that declares one and never writes it — is cut after its first
  block, which is what Jekyll does by default. That last case is a deliberate
  divergence: Jekyll treats a missing marker as "the whole page is the opening",
  which is visibly not what the author meant.
  """

  @doc """
  Split a parsed document into its opening and the rest of it.

  Returns `{nil, document}` when there is nothing to cut, which is the case for
  a document of a single block.

      iex> {:ok, document} = MDEx.parse_document("Opening.\\n\\n<!-- more -->\\n\\nRest.\\n")
      iex> {excerpt, body} = Excerpt.split(document, "<!-- more -->")
      iex> {Enum.count(excerpt.nodes), Enum.count(body.nodes)}
      {1, 1}
  """
  @spec split(MDEx.Document.t(), String.t() | nil) ::
          {MDEx.Document.t() | nil, MDEx.Document.t()}
  def split(%MDEx.Document{nodes: nodes} = document, separator) do
    case split_nodes(nodes, separator) do
      {[], body} ->
        {nil, %MDEx.Document{document | nodes: body}}

      {excerpt, body} ->
        {%MDEx.Document{document | nodes: excerpt}, %MDEx.Document{document | nodes: body}}
    end
  end

  defp split_nodes(nodes, separator) when is_binary(separator) do
    case Enum.split_while(nodes, &(not separator?(&1, separator))) do
      {_nodes, []} -> split_nodes(nodes, nil)
      {excerpt, [_separator | body]} -> {excerpt, body}
    end
  end

  defp split_nodes([], nil), do: {[], []}
  defp split_nodes([only], nil), do: {[], [only]}
  defp split_nodes([first | rest], nil), do: {[first], rest}

  defp separator?(%MDEx.HtmlBlock{literal: literal}, separator),
    do: String.trim(literal) == String.trim(separator)

  defp separator?(_node, _separator), do: false
end
