defmodule ArchiDep.CourseSite.Renderer.RenderOptions do
  @moduledoc """
  What a build wants of the renderer, as opposed to what one document is: the
  Liquid tags that exist, the passes to run over what they produce, and the
  build-wide policies a tag has to obey.

  These are the same for every document of a build, so they are built once and
  shared, and they are the seam the rest of the migration plugs into: a new tag
  is an entry in `tags`, a new rewrite of the output is an entry in `ast_passes`
  or `html_passes`. Keeping them here rather than as arguments means adding one
  changes no signature.
  """

  alias ArchiDep.CourseSite.Renderer.EmojiImages
  alias ArchiDep.CourseSite.Renderer.ExternalLinks
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.PageAssets

  # None of these is a preference. Drawing the emoji of a page is the other half
  # of identifying its headings: a heading's shortcodes are moved out of the
  # text its identifier is slugged from before the page is rendered, so a build
  # that swept none of them would publish anchors named after a decoration it
  # then shows as text. A link that leaves the site opens in a tab of its own
  # wherever the page is read, since it is the same page everywhere. And the
  # file a document refers to next to itself is published under a digested name,
  # so a build resolving none of them would publish pages pointing at names that
  # no longer exist.
  @default_ast_passes [PageAssets]
  @default_html_passes [EmojiImages, ExternalLinks]

  @enforce_keys [:tags, :ast_passes, :html_passes]
  defstruct reveal_all_solutions: false,
            strict_variables: true,
            tags: nil,
            ast_passes: @default_ast_passes,
            html_passes: @default_html_passes

  @type t :: %__MODULE__{
          reveal_all_solutions: boolean(),
          strict_variables: boolean(),
          tags: %{String.t() => module()},
          ast_passes: [module()],
          html_passes: [module()]
        }

  @doc """
  Build the options of a build, raising an `ArgumentError` when one is
  malformed.

  Options:

  - `:reveal_all_solutions` — render every solution regardless of how far the
    course has progressed. A frozen archive of a past edition sets this; the
    edition being taught does not.
  - `:strict_variables` — report a reference to a variable the document was not
    given, instead of rendering nothing. On by default: the content's whole
    variable surface is `{{ page.title }}`, so a typo is a mistake rather than a
    conditional.
  - `:tags` — the Liquid tag table. Defaults to
    `ArchiDep.CourseSite.Renderer.Liquid.Tags.default/0`.
  - `:ast_passes` — `ArchiDep.CourseSite.Renderer.AstPass` modules, run over
    every Markdown document the build converts, whole pages and extracted tag
    bodies alike. Defaults to the one every build wants: resolving what a
    document refers to next to itself with
    `ArchiDep.CourseSite.Renderer.PageAssets`.
  - `:html_passes` — `ArchiDep.CourseSite.Renderer.HtmlPass` modules, run once
    over the finished HTML of a page. Defaults to the two every build wants:
    drawing the page's emoji with `ArchiDep.CourseSite.Renderer.EmojiImages`,
    and opening the links that leave the site in a tab of their own with
    `ArchiDep.CourseSite.Renderer.ExternalLinks`.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) when is_list(opts) do
    %__MODULE__{
      reveal_all_solutions: boolean!(opts, :reveal_all_solutions, false),
      strict_variables: boolean!(opts, :strict_variables, true),
      tags: tags!(opts),
      ast_passes: modules!(opts, :ast_passes, @default_ast_passes),
      html_passes: modules!(opts, :html_passes, @default_html_passes)
    }
  end

  defp boolean!(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_boolean(value) -> value
      value -> raise ArgumentError, "#{inspect(key)} must be a boolean, got: #{inspect(value)}"
    end
  end

  defp tags!(opts) do
    case Keyword.get(opts, :tags, Tags.default()) do
      tags when is_map(tags) -> named_tags!(tags)
      tags -> raise ArgumentError, "Tags must be a map, got: #{inspect(tags)}"
    end
  end

  defp named_tags!(tags) do
    if Enum.all?(tags, fn {name, module} -> is_binary(name) and is_atom(module) end) do
      tags
    else
      raise ArgumentError, "Tags must map tag names to modules, got: #{inspect(tags)}"
    end
  end

  defp modules!(opts, key, default) do
    case Keyword.get(opts, key, default) do
      passes when is_list(passes) ->
        module_list!(passes, key)

      passes ->
        raise ArgumentError, "#{inspect(key)} must be a list of modules, got: #{inspect(passes)}"
    end
  end

  defp module_list!(passes, key) do
    if Enum.all?(passes, &is_atom/1) do
      passes
    else
      raise ArgumentError, "#{inspect(key)} must be a list of modules, got: #{inspect(passes)}"
    end
  end
end
