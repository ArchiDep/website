defmodule Mix.Tasks.Archidep.CourseSite.ProgressSource do
  @moduledoc """
  Where a command-line build of the course material site reads how far the
  course has got.

  A running application reads it from its own database, through
  `ArchiDep.Course.course_sessions/0`. A command has no application running, so
  it is told, by the one `--progress` switch the two commands share, and the
  switch takes three forms:

  - `complete` — a course that is over. Not a source at all: it is derived from
    the course being built (see `ArchiDep.CourseSite.Progress.complete/1`), and
    is refused where it would be a lie about a course still being taught.
  - an `http://` or `https://` URL — the progress route of a running deployment,
    which is how the backup copy and the printed PDFs track the live site.
  - anything else — a file holding the same JSON that route serves, for a
    snapshot handed over by hand.

  Dispatching on the value is what makes a file literally named `complete`, or
  one whose name begins with a URL scheme, unaddressable. Both are worth the
  one knob.

  This is a module of the commands rather than of
  `ArchiDep.CourseSite` — that subsystem must run standalone and reads nothing
  but the filesystem, and a build that can reach the network is a different
  claim. It is not a Mix task: it defines no `run/1`.
  """

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Build.ProgressFile
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.Http
  alias Req.Response

  @forms """
  Say where to read it from with one of:
    --progress complete                   a course that is over (archive builds only)
    --progress https://host/api/progress  a running deployment
    --progress ./progress.json            a snapshot
  """

  @doc """
  What the `--progress` switch was given, as the `:progress` option of
  `ArchiDep.CourseSite.Build.site_inputs/1`.

  `complete_allowed?` says whether the course being built is one that is over —
  an archived edition, or the reference check, which renders every page
  precisely to see whether it resolves. It is both what `--progress` defaults to
  there and the only place the value is accepted: a live or a backup build
  rendered as complete would reveal every answer of a course still being taught,
  and would look entirely normal.
  """
  @spec progress!(String.t() | nil, boolean()) :: [Session.t()] | :complete
  def progress!(value, complete_allowed?)

  def progress!(nil, true), do: :complete

  def progress!(nil, false),
    do: Mix.raise("This build needs to be told how far the course has got.\n\n" <> @forms)

  def progress!("complete", true), do: :complete

  def progress!("complete", false),
    do:
      Mix.raise(
        "Only an archived edition is complete; a build of the edition being taught has to be told how far it has got.\n\n" <>
          @forms
      )

  def progress!("http://" <> _rest = url, _complete_allowed?), do: fetch!(url)
  def progress!("https://" <> _rest = url, _complete_allowed?), do: fetch!(url)
  def progress!(file, _complete_allowed?), do: read!(file)

  defp read!(file) do
    case Build.progress(file) do
      {:ok, sessions} -> sessions
      {:error, errors} -> Mix.raise(unreadable(file, Enum.map(errors, &Build.format_error/1)))
    end
  end

  # The commands compile the application rather than starting it, so the HTTP
  # client's own application is not running unless this asks for it.
  defp fetch!(url) do
    {:ok, _started} = Application.ensure_all_started(:req)

    case Http.get(url, []) do
      {:ok, %Response{status: 200, body: body}} ->
        sessions!(url, body)

      {:ok, %Response{status: status}} ->
        Mix.raise(unreadable(url, ["the server answered #{status}"]))

      {:error, error} ->
        Mix.raise(unreadable(url, [Exception.message(error)]))
    end
  end

  # Req decodes a JSON response body for us; anything else is a route that is
  # not the one this was pointed at.
  defp sessions!(url, body) when is_map(body) do
    case ProgressFile.sessions(body) do
      {:ok, sessions} -> sessions
      {:error, error} -> Mix.raise(unreadable(url, [ProgressFile.format_error(error)]))
    end
  end

  defp sessions!(url, _body),
    do: Mix.raise(unreadable(url, ["the response was not a JSON object"]))

  defp unreadable(source, reasons),
    do:
      "The progress through the course could not be read from #{source}:\n" <>
        Enum.map_join(reasons, "\n", &("  " <> &1))
end
