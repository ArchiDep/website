defmodule ArchiDep.CourseSite.Urls.PageAssetManifest do
  @moduledoc """
  The digested names of the assets co-located with course pages — the images and
  PDFs authors write next to a document and reference relatively.

  Entries are keyed by the asset's **output** path within the build, without the
  deployment mount point or the year prefix, and hold the digested **file name**
  only: digesting renames a file, it never moves it to another directory. The
  build step owns the mapping from an output path back to the source file it was
  copied from, so `ArchiDep.CourseSite.Urls` never reads the source tree.

  An asset is also known by the name it ends up under, which is what makes
  looking one up **idempotent**: the same reference can be resolved twice, and
  the second time is the first time's answer. The renderer relies on it, since
  the Liquid stage resolves the references written with `relative_file_url` and
  the sweep over what it produces then sees the digested names those emitted.
  """

  alias ArchiDep.CourseSite.Urls.UrlPath

  @enforce_keys [:page_assets, :digested]
  defstruct [:page_assets, :digested]

  @type t :: %__MODULE__{
          page_assets: %{String.t() => String.t()},
          digested: %{String.t() => String.t()}
        }

  @doc """
  Build a page asset manifest from output paths to digested file names.
  """
  @spec new(%{String.t() => String.t()}) :: t()
  def new(page_assets) when is_map(page_assets),
    do: %__MODULE__{page_assets: page_assets, digested: digested(page_assets)}

  @doc """
  Look up the digested file name of a page asset by its output path, whether it
  is the path the asset is written under or the one it is published under.

      iex> manifest = PageAssetManifest.new(%{"/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"})
      iex> PageAssetManifest.fetch(manifest, "/course/101-command-line/images/cli.jpg")
      {:ok, "cli-9f8e7d.jpg"}

      iex> manifest = PageAssetManifest.new(%{"/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"})
      iex> PageAssetManifest.fetch(manifest, "/course/101-command-line/images/cli-9f8e7d.jpg")
      {:ok, "cli-9f8e7d.jpg"}

      iex> PageAssetManifest.fetch(PageAssetManifest.new(%{}), "/course/101-command-line/images/cli.jpg")
      :error
  """
  @spec fetch(t(), String.t()) :: {:ok, String.t()} | :error
  def fetch(%__MODULE__{page_assets: page_assets, digested: digested}, output_path)
      when is_binary(output_path) do
    case Map.fetch(page_assets, output_path) do
      {:ok, file_name} -> {:ok, file_name}
      :error -> Map.fetch(digested, output_path)
    end
  end

  # Digesting renames a file within its own directory, so the path an asset is
  # published under is its own directory and the name it was given.
  defp digested(page_assets) do
    Map.new(page_assets, fn {output_path, file_name} ->
      {UrlPath.dirname(output_path) <> file_name, file_name}
    end)
  end
end
