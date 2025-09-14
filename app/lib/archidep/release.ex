defmodule ArchiDep.Release do
  @moduledoc """
  Used for executing release tasks in production without Mix installed.
  """

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerConnection

  @app :archidep

  @type ssh_student_option :: {:timeout, pos_integer()}

  @spec ssh_student(String.t(), String.t() | list(String.t())) ::
          {:ok, %{exit_code: 0..255, stdout: String.t(), stderr: String.t()}}
          | {:error, {:multiple_students_found, list(String.t())}}
          | {:error, :student_not_found}
  @spec ssh_student(String.t(), String.t() | list(String.t()), list(ssh_student_option())) ::
          {:ok, %{exit_code: 0..255, stdout: String.t(), stderr: String.t()}}
          | {:error, {:multiple_students_found, list(String.t())}}
          | {:error, :student_not_found}
  def ssh_student(student_name, args, opts \\ [])

  def ssh_student(student_name, args, opts) when is_list(args) do
    command = shell_escape(args)
    ssh_student(student_name, command, opts)
  end

  def ssh_student(student_name, command, opts) do
    now = DateTime.utc_now()
    timeout = Keyword.get(opts, :timeout, 30_000)

    with {:ok, student} <- Student.find_active_registered_student_by_name(student_name, now),
         {:ok, server} <- Server.find_active_server_for_group_member(student.id),
         {:ok, stdout, stderr, exit_code} <-
           ServerConnection.run_command(server, command, timeout) do
      # credo:disable-for-next-line Credo.Check.Refactor.IoPuts
      IO.puts(
        "EXIT CODE: #{exit_code}\n\nSTDOUT:#{format_stream(stdout)}\n\nSTDERR:#{format_stream(stderr)}"
      )

      {:ok,
       %{
         exit_code: exit_code,
         stdout: "#{byte_size(stdout)} byte(s)",
         stderr: "#{byte_size(stderr)} byte(s)"
       }}
    end
  end

  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _fun_return, _apps} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @spec rollback(Ecto.Repo.t(), integer(), :yes_i_know_what_i_am_doing) :: :ok
  def rollback(repo, version, :yes_i_know_what_i_am_doing) do
    load_app()

    {:ok, _fun_return, _apps} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))

    :ok
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)

  defp format_stream(std), do: std |> String.trim() |> format_maybe_empty_stream()
  defp format_maybe_empty_stream(""), do: " (empty)"
  defp format_maybe_empty_stream(stream), do: "\n#{stream}"

  defp shell_escape(args),
    do:
      Enum.map_join(args, " ", fn s ->
        if String.match?(s, ~r/[^A-Za-z0-9_\/:=\-]/) do
          s = "'" <> String.replace(s, "'", "'\\''") <> "'"

          s
          # unduplicate single-quote at the beginning
          |> String.replace(~r/^('')+/, "")
          # remove non-escaped single-quote if there are enclosed between 2 escaped
          |> String.replace(~r/\\'''/, "\\'")
        else
          s
        end
      end)
end
