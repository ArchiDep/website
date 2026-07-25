defmodule ArchiDep.CourseSite.Renderer.Liquid.Filters do
  @moduledoc """
  The filters a course document may use, built for the document that is being
  rendered.

  `Solid` hands a custom filter its name and its arguments and nothing else — no
  context — so a filter that needs to know which page it is on cannot be a plain
  function. It is built per document instead, closing over the rendering
  context.

  There is one filter, and it is about assets sitting next to a page: `{{
  'images/analytical-engine.jpg' | relative_file_url }}`. It matters mostly to
  slides, which is where all of its uses are, and it is worth knowing that it
  does nothing at all today — Jekyll's version silently returns its argument
  because of a guard that never passes in the hook it runs in.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls

  @type filters :: (String.t(), [term()] ->
                      {:ok, term()} | {:error, Exception.t(), term()} | :error)

  @doc """
  Build the filters of one document.
  """
  @spec build(RenderContext.t()) :: filters()
  def build(%RenderContext{} = context) do
    fn
      "relative_file_url", [path | _rest] when is_binary(path) ->
        relative_file_url(context, path)

      _name, _arguments ->
        :error
    end
  end

  defp relative_file_url(context, path) do
    case Urls.resolve(context.urls, {:page_asset, context.page, path}, context.page) do
      {:ok, url} ->
        {:ok, url}

      {:error, error} ->
        # The path the author wrote is the fallback: the page still renders, and
        # the build reports the asset that is missing.
        {:error, RenderError.new({:url, error}, context.source_path), path}
    end
  end
end
