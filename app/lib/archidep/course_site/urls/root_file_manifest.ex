defmodule ArchiDep.CourseSite.Urls.RootFileManifest do
  @moduledoc """
  The files a build publishes at its mount point rather than under its edition —
  the favicon and the marks beside it.

  Unlike the other manifests there is nothing to map: a root file is published
  under the name it is referred to by, digested by nothing. What this answers is
  whether the build publishes one at all, which is the whole of its purpose —
  the chrome names these files and
  [`ArchiDep.CourseSite.Build`](`ArchiDep.CourseSite.Build.root_files/0`)
  publishes them, and nothing else would notice the two disagreeing. A
  `{:root_file, _}` reference to a file no build carries is a broken picture on
  every page rather than a broken link the [link
  check](`ArchiDep.CourseSite.Build.LinkCheck`) could find, since that check
  deliberately leaves root-anchored URLs alone: a build does not own everything
  under its mount point.

  Keyed by output path — with a leading slash, no mount point and no edition
  prefix — which is the way the rest of the subsystem names a file a build
  wrote.
  """

  @enforce_keys [:paths]
  defstruct [:paths]

  @type t :: %__MODULE__{paths: MapSet.t(String.t())}

  @doc """
  Build a root file manifest from the output paths of the files a build
  publishes at its mount point.
  """
  @spec new(Enumerable.t(String.t())) :: t()
  def new(paths), do: %__MODULE__{paths: MapSet.new(paths)}

  @doc """
  Whether the build publishes a file at its mount point.

      iex> RootFileManifest.member?(RootFileManifest.new(["/favicon.ico"]), "/favicon.ico")
      true

      iex> RootFileManifest.member?(RootFileManifest.new([]), "/favicon.ico")
      false
  """
  @spec member?(t(), String.t()) :: boolean()
  def member?(%__MODULE__{paths: paths}, path) when is_binary(path),
    do: MapSet.member?(paths, path)
end
