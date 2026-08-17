defmodule ArchiDep.CourseSite.Archives do
  @moduledoc """
  The editions of the course that came before this one, and what each of their
  pages has become in it.

  This is the other half of a decision made where the archive banner is emitted:
  a finished edition goes on serving its own content at its own URLs and never
  redirects away from itself, but every one of its pages carries a link to the
  current version of that page. The link cannot name its target, because the
  correspondence changes through the year as the course is reworked and an
  archive is frozen bytes that can never be re-pointed. So it names the archived
  page instead — `/latest?to=/2025/course/104-ssh/` — and this is what answers.

  That indirection is what lets an archive be kept as output rather than as
  sources: its links stay right without it ever being rebuilt.

  Like `ArchiDep.CourseSite.Material`, and unlike everything else in this
  namespace, it is an **edition-bound** value: the mapping is a function of the
  archives *and* of the course now compiled, so it belongs to this checkout. It
  is compiled rather than read at request time for the reason the guarantee
  exists at all — an archived page that the current edition can no longer
  account for must fail this application's build, naming it, rather than reach a
  reader as a dead link years later.

  It is a separate module from `Material` because it asks a recompilation
  question `Material` cannot: an edition *archived* since is a new file in a
  directory `Material` does not watch.

  ## When it is compiled again

  The same two mechanisms `ArchiDep.CourseSite.Material` documents, over the
  archives directory and the overrides file: every file that is there is an
  `@external_resource`, so editing or deleting one recompiles this module, and
  `__mix_recompile__?/0` compares a digest of the directory's file *names*,
  which is what catches an edition being archived.

  ## When the application is gone

  `mapping/0` is plain data, keyed by exactly the value the banner sends, and
  that is deliberate rather than incidental. When the course ends for good and
  this application goes down, the archives outlive it on a static host, and one
  file reading `location.search` against that same map answers these URLs with
  no application at all. Nothing here may become a set of function clauses.
  """

  alias ArchiDep.CourseSite.Archives.Completeness
  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.Archives.Mapping
  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.PageRef

  # Resolved against this file rather than through a configuration knob, for the
  # reason `ArchiDep.CourseSite.Material` gives: these can only ever mean the
  # course of the repository the application was compiled from.
  @course_dir Path.expand("../../../../course", __DIR__)
  @archives_dir Path.join(@course_dir, "archives")
  @overrides_file Path.join(@course_dir, "archives.yml")

  @external_resource @overrides_file
  for file <- Build.archive_files(@archives_dir) do
    @external_resource Path.join(@archives_dir, file)
  end

  @archives_digest Build.archives_digest(@archives_dir)
  @manifests Build.archives!(@archives_dir)
  @mapping Build.archive_mapping!(@manifests, @overrides_file, Material.structure())

  @entries Mapping.entries(@mapping)
  @editions Map.new(@manifests, &{&1.edition, Manifest.edition_paths(&1)})

  @doc """
  What the current edition holds in place of the archived page a reader arrived
  with.

  The value is the one the archive's banner sent, and it is only ever looked up
  here — never joined onto a path, never redirected to. `:gone` carries the
  matched key so that a page saying there is no equivalent can still link back
  to the archive without echoing what it was given; `:error` is anything this
  application never published.
  """
  @spec resolve(term()) :: {:ok, PageRef.t()} | {:gone, String.t()} | :error
  def resolve(to), do: Mapping.fetch(@mapping, to)

  @doc """
  What every page of every archived edition has become, keyed by the archived
  page's own path.
  """
  @spec mapping() :: %{String.t() => Mapping.entry()}
  def mapping, do: @entries

  @doc """
  Which pages a host must hold to serve every archived edition, keyed by the
  edition.

  This is the other half of what the manifests say. `mapping/0` answers a reader
  who arrived at an archived page; this says what "the archives are all here"
  means for a host that keeps them beside the edition it renders itself, which
  is the only authoritative answer to whether a deployment is complete.
  """
  @spec editions() :: %{String.t() => [String.t()]}
  def editions, do: @editions

  @doc """
  Whether this deployment holds the archived editions it is supposed to serve.

  The editions and their pages are the compiled facts above; where a host keeps
  them and which edition it renders itself are the two things it takes from
  configuration.
  """
  @spec completeness() :: Completeness.t()
  def completeness do
    config = Application.get_env(:archidep, :course_site, [])

    Completeness.check(
      Keyword.get(config, :archives_dir),
      @editions,
      Keyword.get(config, :version)
    )
  end

  @doc """
  Whether an edition has been archived or unarchived since this module was
  compiled.
  """
  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @archives_digest != Build.archives_digest(@archives_dir)
end
