defmodule ArchiDep.CourseSite.Renderer.PageAssets do
  @moduledoc """
  Resolves the files a document refers to next to itself.

  This is the document's half of the rewrite
  (`ArchiDep.CourseSite.Renderer.AssetReferences` is the text's): the URL of
  every image and of every link, plus the references written in the raw HTML a
  document embeds, which is markup as far as the document is concerned and text
  as far as the reference is concerned. What a reference has to look like to be
  one, and why a missing image fails the build where a missing link does not,
  are that module's rules.

  It runs on the document rather than on the finished page for two reasons. A
  page's HTML is what a tag's output has already become, so a rewrite there
  would see the code the highlighter emits as if a page had written it; and a
  reference written in the body of a block tag is in a document of its own,
  which is exactly what an `ArchiDep.CourseSite.Renderer.AstPass` sees and a
  pass over the page does not.
  """

  @behaviour ArchiDep.CourseSite.Renderer.AstPass

  alias ArchiDep.CourseSite.Renderer.AssetReferences
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @doc """
  Resolve what a document refers to next to itself.
  """
  @impl ArchiDep.CourseSite.Renderer.AstPass
  @spec run(MDEx.Document.t(), RenderContext.t()) ::
          {MDEx.Document.t(), [RenderError.t()]}
  def run(%MDEx.Document{} = document, %RenderContext{} = context) do
    {resolved, errors} =
      document
      |> Enum.filter(&refers?/1)
      |> Enum.reduce({%{}, []}, fn node, {resolved, errors} ->
        {node_resolved, node_errors} = resolve(node, context)
        {Map.put(resolved, node, node_resolved), errors ++ node_errors}
      end)

    {MDEx.Document.update_nodes(document, &refers?/1, &Map.fetch!(resolved, &1)),
     Enum.uniq(errors)}
  end

  defp refers?(%MDEx.Image{}), do: true
  defp refers?(%MDEx.Link{}), do: true
  defp refers?(%MDEx.HtmlBlock{}), do: true
  defp refers?(%MDEx.HtmlInline{}), do: true
  defp refers?(_node), do: false

  defp resolve(%MDEx.Image{} = node, context) do
    {url, errors} = AssetReferences.resolve(node.url, :image, context)
    {%MDEx.Image{node | url: url}, errors}
  end

  defp resolve(%MDEx.Link{} = node, context) do
    {url, errors} = AssetReferences.resolve(node.url, :link, context)
    {%MDEx.Link{node | url: url}, errors}
  end

  defp resolve(%MDEx.HtmlBlock{} = node, context) do
    {literal, errors} = AssetReferences.rewrite(node.literal, :html, context)
    {%MDEx.HtmlBlock{node | literal: literal}, errors}
  end

  defp resolve(%MDEx.HtmlInline{} = node, context) do
    {literal, errors} = AssetReferences.rewrite(node.literal, :html, context)
    {%MDEx.HtmlInline{node | literal: literal}, errors}
  end
end
