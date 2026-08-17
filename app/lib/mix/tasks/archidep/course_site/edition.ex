defmodule Mix.Tasks.Archidep.CourseSite.Edition do
  @shortdoc "Print the edition of the course this checkout holds"

  @moduledoc """
  Print the edition the `course_site` configuration says this checkout holds,
  i.e. the starting year of the academic year.

      mix archidep.course_site.edition

  It exists for whatever publishes a build and has to name the directory it goes
  into: the edition rendered and the directory it is published as are then one
  fact, read from the same place `mix archidep.course_site.build` defaults its
  own `--version` to.

  It is the edition alone that is printed, on a line of its own, so that the
  output can be read by a shell.
  """

  use Mix.Task

  @requirements ["compile"]

  @impl Mix.Task
  def run([]) do
    configured = Application.get_env(:archidep, :course_site, [])

    case Keyword.get(configured, :version) do
      nil -> Mix.raise("No edition is configured")
      version -> Mix.shell().info(version)
    end
  end

  def run(_args), do: Mix.raise("This task takes no arguments")
end
