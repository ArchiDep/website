defmodule ArchiDep.CourseSite.Build.Site.Options do
  @moduledoc """
  What a build decided, as against what it read.

  The division is the one `ArchiDep.CourseSite.Renderer.RenderContext` and
  `ArchiDep.CourseSite.Renderer.RenderOptions` already draw: the inputs beside
  this are the course as it is written, and these are the choices that make one
  build of it differ from another — where it is published, what it is wrapped
  in, and what produced it.
  """

  alias ArchiDep.CourseSite.Layout.Minimal
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext

  @enforce_keys [:urls, :site]
  defstruct [:urls, :site, layout: Minimal, render_options: nil]

  @type t :: %__MODULE__{
          urls: UrlContext.t(),
          site: SiteInfo.t(),
          layout: module(),
          render_options: RenderOptions.t()
        }

  @doc """
  State what a build is, raising an `ArgumentError` when a value is malformed.

  Options:

  - `:urls` (required) — the build, as an `ArchiDep.CourseSite.Urls.UrlContext`.
  - `:site` (required) — what produced it, as an `ArchiDep.CourseSite.SiteInfo`.
  - `:layout` — the `ArchiDep.CourseSite.Layout` its pages are wrapped in.
    Defaults to `ArchiDep.CourseSite.Layout.Minimal`.
  - `:render_options` — the renderer's own
    `ArchiDep.CourseSite.Renderer.RenderOptions`. Defaults to
    `RenderOptions.new/0`, which is what every real build wants: its passes are
    not preferences, and a build that dropped one would publish wrong anchors
    and undigested file names.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      urls: urls!(opts),
      site: site!(opts),
      layout: layout!(opts),
      render_options: render_options!(opts)
    }
  end

  defp urls!(opts) do
    case Keyword.fetch!(opts, :urls) do
      %UrlContext{} = urls ->
        urls

      other ->
        raise ArgumentError,
              "URL context must be a #{inspect(UrlContext)}, got: #{inspect(other)}"
    end
  end

  defp site!(opts) do
    case Keyword.fetch!(opts, :site) do
      %SiteInfo{} = site ->
        site

      other ->
        raise ArgumentError, "Site info must be a #{inspect(SiteInfo)}, got: #{inspect(other)}"
    end
  end

  defp layout!(opts) do
    case Keyword.get(opts, :layout, Minimal) do
      layout when is_atom(layout) and not is_nil(layout) ->
        layout

      other ->
        raise ArgumentError, "Layout must be a module, got: #{inspect(other)}"
    end
  end

  defp render_options!(opts) do
    case Keyword.get(opts, :render_options, RenderOptions.new()) do
      %RenderOptions{} = options ->
        options

      other ->
        raise ArgumentError,
              "Render options must be a #{inspect(RenderOptions)}, got: #{inspect(other)}"
    end
  end
end
