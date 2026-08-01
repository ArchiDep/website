defmodule ArchiDep.CourseSite.Build.Site.Inputs do
  @moduledoc """
  Everything a build read before it decided anything.

  `ArchiDep.CourseSite.Build.site_inputs/1` fills it and
  `ArchiDep.CourseSite.Build.Site.plan/2` is a function of it: gathering the
  reads into one value is what makes that claim checkable. Hand a planner this
  and nothing else, and there is no file left for it to reach for half way
  through.

  The home page is read like any other page and sits in `sources` under `:home`,
  but where it was read from is a field of its own: it is not in the content
  directory (`ArchiDep.CourseSite.Build.home_source/1` says why), so the content
  tree, which is where every other page's source path comes from, has nothing to
  say about it.
  """

  alias ArchiDep.CourseSite.Build.ContentTree
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest

  @enforce_keys [
    :tree,
    :sources,
    :home_source_path,
    :structure,
    :progress,
    :includes,
    :assets,
    :page_assets
  ]
  defstruct [
    :tree,
    :sources,
    :home_source_path,
    :structure,
    :progress,
    :includes,
    :assets,
    :page_assets
  ]

  @type t :: %__MODULE__{
          tree: ContentTree.t(),
          sources: %{PageRef.t() => Source.t()},
          home_source_path: String.t(),
          structure: Structure.t(),
          progress: Progress.t(),
          includes: %{String.t() => Solid.Template.t()},
          assets: AssetManifest.t(),
          page_assets: PageAssetManifest.t()
        }
end
