defmodule ArchiDep.CourseSite.Renderer.RenderContext do
  @moduledoc """
  Everything the renderer needs to turn one course document into a page: the
  document itself, which page of which build it is, and what a tag inside it is
  allowed to know.

  It is built once per document and never updated. Anything a tag produces
  besides HTML — a collected identifier, an error — travels back through
  `Solid`'s own context instead, so that there is one place a result accumulates
  rather than two orderings to reconcile.

  The URL context is in here rather than reachable from a tag directly because
  `ArchiDep.CourseSite.Urls` also needs to know which page is being rendered:
  that is what makes a link to a heading of this very page come out as a bare
  `#fragment`.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Urls.UrlContext

  @enforce_keys [:source, :source_path, :urls, :page, :options]
  defstruct [:source, :source_path, :urls, :page, :options, page_variables: %{}, includes: %{}]

  @type t :: %__MODULE__{
          source: Source.t(),
          source_path: String.t(),
          urls: UrlContext.t(),
          page: PageRef.t(),
          page_variables: %{String.t() => term()},
          includes: %{String.t() => Solid.Template.t()},
          options: RenderOptions.t()
        }

  @doc """
  Build the rendering context of one document, raising an `ArgumentError` when a
  value is malformed.

  Options:

  - `:source` (required) — the document, already taken apart by
    `ArchiDep.CourseSite.Renderer.Source.parse/1`. The caller parses it rather
    than the renderer because the build reads the front matter to work out what
    the document *is* before it renders it.
  - `:source_path` (required) — the path of the file, e.g.
    `"_course/507-dns/subject.md"`. Only ever used to say where a problem is.
  - `:urls` (required) — the build, as an `ArchiDep.CourseSite.Urls.UrlContext`.
  - `:page` (required) — the page being rendered, as an
    `ArchiDep.CourseSite.PageRef`.
  - `:page_variables` — what `{{ page.x }}` resolves to, on top of the front
    matter. These are the values the build derives (a chapter number, a slug),
    and they win over the front matter, which is the precedence Jekyll's
    generator has today.
  - `:includes` — the partials `{% include %}` may pull in, already parsed by
    `ArchiDep.CourseSite.Renderer.compile_includes/1`.
  - `:options` — the build's `ArchiDep.CourseSite.Renderer.RenderOptions`.
    Defaults to `RenderOptions.new/0`.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      source: source!(opts),
      source_path: source_path!(opts),
      urls: urls!(opts),
      page: page!(opts),
      page_variables: page_variables!(opts),
      includes: includes!(opts),
      options: options!(opts)
    }
  end

  @doc """
  What `{{ page.… }}` resolves to: the document's front matter with the build's
  own values layered on top.
  """
  @spec page_variables(t()) :: %{String.t() => term()}
  def page_variables(%__MODULE__{source: source, page_variables: variables}),
    do: Map.merge(source.front_matter, variables)

  defp source!(opts) do
    case Keyword.fetch!(opts, :source) do
      %Source{} = source -> source
      other -> raise ArgumentError, "Source must be a #{inspect(Source)}, got: #{inspect(other)}"
    end
  end

  defp source_path!(opts) do
    case Keyword.fetch!(opts, :source_path) do
      path when is_binary(path) and path != "" ->
        path

      other ->
        raise ArgumentError, "Source path must be a non-empty string, got: #{inspect(other)}"
    end
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

  defp page!(opts) do
    case Keyword.fetch!(opts, :page) do
      :home -> :home
      {:document, %DocumentRef{}} = page -> page
      {:cheatsheet, slug} = page when is_binary(slug) -> page
      other -> raise ArgumentError, "Page must be a page reference, got: #{inspect(other)}"
    end
  end

  defp page_variables!(opts) do
    case Keyword.get(opts, :page_variables, %{}) do
      variables when is_map(variables) -> named_variables!(variables)
      other -> raise ArgumentError, "Page variables must be a map, got: #{inspect(other)}"
    end
  end

  defp named_variables!(variables) do
    if Enum.all?(variables, fn {key, _value} -> is_binary(key) end) do
      variables
    else
      raise ArgumentError, "Page variables must be keyed by strings, got: #{inspect(variables)}"
    end
  end

  defp includes!(opts) do
    case Keyword.get(opts, :includes, %{}) do
      includes when is_map(includes) -> parsed_includes!(includes)
      other -> raise ArgumentError, "Includes must be a map, got: #{inspect(other)}"
    end
  end

  defp parsed_includes!(includes) do
    if Enum.all?(includes, &match?({path, %Solid.Template{}} when is_binary(path), &1)) do
      includes
    else
      raise ArgumentError,
            "Includes must map paths to parsed templates, got: #{inspect(includes)}"
    end
  end

  defp options!(opts) do
    case Keyword.get(opts, :options, RenderOptions.new()) do
      %RenderOptions{} = options ->
        options

      other ->
        raise ArgumentError,
              "Options must be a #{inspect(RenderOptions)}, got: #{inspect(other)}"
    end
  end
end
