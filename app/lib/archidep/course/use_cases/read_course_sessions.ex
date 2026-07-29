defmodule ArchiDep.Course.UseCases.ReadCourseSessions do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Session

  # Under the application's own `priv` rather than in the course directory,
  # which a release does not ship.
  @progress_file "course/progress.json"

  # Nothing to authorize: how far the course has got is public, and the command
  # use cases of this context authorize because they act on a class or a
  # student, neither of which this touches.
  @spec course_sessions() :: [Session.t()]
  @spec course_sessions(Path.t()) :: [Session.t()]
  def course_sessions(file \\ progress_file()) do
    case Build.progress(file) do
      {:ok, sessions} ->
        sessions

      {:error, errors} ->
        raise "The progress through the course could not be read:\n" <>
                Enum.map_join(errors, "\n", &("  " <> Build.format_error(&1)))
    end
  end

  @doc """
  Where the application keeps its record of how far the course has got.
  """
  @spec progress_file() :: Path.t()
  def progress_file, do: Application.app_dir(:archidep, Path.join("priv", @progress_file))
end
