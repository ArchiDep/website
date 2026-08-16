defmodule ArchiDep.CourseSite.Renderer.RenderContext do
  @moduledoc """
  Everything the renderer needs to turn one course document into a page: the
  document itself, which page of which build it is, and what a tag inside it is
  allowed to know.

  It is built once per document, and the renderer settles one thing on it before
  rendering begins — the document's link reference definitions, whose
  destinations are Liquid like the rest of the file. Nothing updates it after
  that: anything a tag produces besides HTML — a collected identifier, an error
  — travels back through `Solid`'s own context instead, so that there is one
  place a result accumulates rather than two orderings to reconcile.

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
  defstruct [
    :source,
    :source_path,
    :urls,
    :page,
    :options,
    :link_references,
    page_variables: %{},
    includes: %{},
    solutions: :revealed
  ]

  @typedoc """
  Whether this page shows the answers it holds, which is a decision the build
  has already made: a chapter's solutions are revealed once the course has
  covered it. The renderer is told the answer rather than the chapter's status,
  so that it never has to know how far the course has got or where the threshold
  is.
  """
  @type solutions :: :revealed | :hidden

  @type t :: %__MODULE__{
          source: Source.t(),
          source_path: String.t(),
          urls: UrlContext.t(),
          page: PageRef.t(),
          page_variables: %{String.t() => term()},
          includes: %{String.t() => Solid.Template.t()},
          options: RenderOptions.t(),
          solutions: solutions(),
          link_references: [{String.t(), String.t()}]
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
    `"chapters/507-dns/subject.md"`. Only ever used to say where a problem is.
  - `:urls` (required) — the build, as an `ArchiDep.CourseSite.Urls.UrlContext`.
  - `:page` (required) — the page being rendered, as an
    `ArchiDep.CourseSite.PageRef`.
  - `:page_variables` — what `{{ page.x }}` resolves to, on top of the front
    matter. These are the values the build derives (a chapter number, a slug),
    and they win over the front matter: what a document states about itself
    cannot override what its place in the course says it is.
  - `:includes` — the partials `{% include %}` may pull in, already parsed by
    `ArchiDep.CourseSite.Renderer.compile_includes/1`.
  - `:options` — the build's `ArchiDep.CourseSite.Renderer.RenderOptions`.
    Defaults to `RenderOptions.new/0`.
  - `:solutions` — whether this page shows the answers it holds, `:revealed` or
    `:hidden`. The caller decides, from the chapter's progress; defaults to
    `:revealed`, which is what a caller with no progress to consult wants — the
    extraction of a page's headings, the check that renders every document, and
    a frozen archive of a finished year.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    source = source!(opts)

    %__MODULE__{
      source: source,
      source_path: source_path!(opts),
      urls: urls!(opts),
      page: page!(opts),
      page_variables: page_variables!(opts),
      includes: includes!(opts),
      options: options!(opts),
      solutions: solutions!(opts),
      link_references: source.link_references
    }
  end

  @doc """
  The same context, with the document's link reference definitions as they read
  once their Liquid has been expanded.

  A destination may be a `{% link %}`, and a definition is appended to fragments
  of the document that are converted on their own — so one that still said what
  the file writes would put raw Liquid inside every block tag of the page. The
  renderer settles this before it renders the body, since a block tag's body is
  converted while the body is being expanded, long before the definitions at the
  bottom of the file are reached.
  """
  @spec resolve_link_references(t(), [{String.t(), String.t()}]) :: t()
  def resolve_link_references(%__MODULE__{} = context, references) when is_list(references),
    do: %__MODULE__{context | link_references: references}

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

  defp solutions!(opts) do
    case Keyword.get(opts, :solutions, :revealed) do
      solutions when solutions in [:revealed, :hidden] ->
        solutions

      other ->
        raise ArgumentError, "Solutions must be :revealed or :hidden, got: #{inspect(other)}"
    end
  end
end
