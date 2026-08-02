defmodule Mix.Tasks.Archidep.CourseSite.Archives do
  @shortdoc "Record what an edition of the course published, for the /latest resolver"

  @moduledoc """
  Write the archive manifest of an edition: every page it published, with the
  path it was served at and the identity this edition gave it.

      mix archidep.course_site.archives

  This is step three of the year-end rollover, run once against the content of
  the edition that is ending, and the file it writes is committed. From then on
  it is that edition's whole record: `ArchiDep.CourseSite.Archives` resolves the
  `/latest?to=…` link on every page of the frozen archive against it, and the
  archive itself is never read again.

  It records the identities rather than leaving them to be worked out later
  because this is the last moment anything knows them. The numbering, the
  slugging and the shape of a URL are all free to change in a later edition, and
  a parser written then would be that edition's grammar applied to an archive it
  never described.

  Re-running it on unchanged content rewrites an identical file, so a manifest
  that turns out to be wrong can be corrected by fixing the content and running
  it again — as long as the edition's own bytes have not yet been frozen.

  Options:

  - `--course` — the course material directory. Defaults to `../course`.
  - `--content` — the course collections directory. Defaults to the
    `collections` directory of the course.
  - `--declarations` — what the course declares about itself. Defaults to the
    `_data/course.yml` of the course.
  - `--version` — the edition being recorded, i.e. the starting year of the
    academic year. Defaults to the edition the application's `course_site`
    configuration says this checkout holds.
  - `--output` — where to write. Defaults to the `archives/<version>.json` of
    the course.
  """

  use Mix.Task

  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.Build

  @requirements ["app.config"]

  @app_dir Path.expand("../../../../..", __DIR__)

  @switches [
    course: :string,
    content: :string,
    declarations: :string,
    version: :string,
    output: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, [], []} = OptionParser.parse(args, strict: @switches)

    course_dir = Keyword.get(opts, :course, Path.join(@app_dir, "../course"))
    edition = edition!(opts)

    manifest =
      Manifest.of(
        edition,
        Build.course!(
          Keyword.get(opts, :content, Path.join(course_dir, "collections")),
          Keyword.get(opts, :declarations, Path.join(course_dir, "_data/course.yml"))
        )
      )

    file =
      Keyword.get(opts, :output, Path.join([course_dir, "archives", "#{edition}.json"]))

    write!(file, Manifest.to_json(manifest))

    Mix.shell().info(
      "Recorded the #{length(manifest.pages)} pages of edition #{edition} in #{file}"
    )
  end

  defp edition!(opts), do: Keyword.get_lazy(opts, :version, &configured_edition!/0)

  defp configured_edition! do
    configured = Application.get_env(:archidep, :course_site, [])

    case Keyword.get(configured, :version) do
      nil -> Mix.raise("No edition is configured; say which one with --version")
      version -> version
    end
  end

  defp write!(file, contents) do
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
