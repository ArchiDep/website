defmodule ArchiDep.CourseSite.Urls.PageAssetManifest do
  @moduledoc """
  The digested names of the assets co-located with course pages — the images and
  PDFs authors write next to a document and reference relatively.

  Entries are keyed by the asset's **output** path within the build, without the
  deployment mount point or the year prefix, and hold the digested **file name**
  only: digesting renames a file, it never moves it to another directory. The
  build step owns the mapping from an output path back to the source file it was
  copied from, so `ArchiDep.CourseSite.Urls` never reads the source tree.
  """

  @enforce_keys [:page_assets]
  defstruct [:page_assets]

  @type t :: %__MODULE__{page_assets: %{String.t() => String.t()}}

  @doc """
  Build a page asset manifest from output paths to digested file names.
  """
  @spec new(%{String.t() => String.t()}) :: t()
  def new(page_assets) when is_map(page_assets), do: %__MODULE__{page_assets: page_assets}

  @doc """
  Look up the digested file name of a page asset by its output path.

      iex> manifest = PageAssetManifest.new(%{"/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"})
      iex> PageAssetManifest.fetch(manifest, "/course/101-command-line/images/cli.jpg")
      {:ok, "cli-9f8e7d.jpg"}

      iex> PageAssetManifest.fetch(PageAssetManifest.new(%{}), "/course/101-command-line/images/cli.jpg")
      :error
  """
  @spec fetch(t(), String.t()) :: {:ok, String.t()} | :error
  def fetch(%__MODULE__{page_assets: page_assets}, output_path) when is_binary(output_path),
    do: Map.fetch(page_assets, output_path)
end
