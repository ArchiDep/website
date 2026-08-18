defmodule Mix.Tasks.Archidep.UaInspector.Download do
  @shortdoc "Download the user agent database, keeping the last copy that worked"

  @moduledoc """
  Download the [UAInspector](https://hexdocs.pm/ua_inspector/readme.html)
  database — the ~30 files describing the browsers, devices and bots the
  application recognises user agent strings by.

      mix archidep.ua_inspector.download

  This wraps `mix ua_inspector.download`, which fetches every file from a remote
  source and fails the whole download when any single request times out. The
  data changes a few times a year, so a copy that is a day old is serviceable
  and a build has no business failing over a slow response. This task therefore
  keeps the last copy that worked in a **cache directory** and falls back on it,
  with a warning, when the download fails. It fails only when the download fails
  *and* there is nothing cached to fall back on.

  Each attempt downloads into a staging directory inside the cache rather than
  over the database itself, so a download that dies halfway through cannot leave
  a half-updated database behind. Only a download that got every file is
  promoted to being the cached copy.

  Options:

  - `--attempts` — how many times to try downloading before giving up and
    falling back on the cache. Defaults to `3`.
  - `--offline` — do not download at all; restore the cached copy, and fail if
    there is none.
  - `--if-missing` — do nothing at all when the database is already there. For
    the development container, whose entrypoint runs this on every start.
  - `--database` — the directory to put the database in. Defaults to the one
    UAInspector reads it from, which is the only one the running application
    looks in.

  The cache directory is `$ARCHIDEP_UA_INSPECTOR_CACHE_DIR`, defaulting to the
  application's own `tmp/ua_inspector`. Point it at whatever a given environment
  keeps between runs: a bind mount in development, a cache action in CI, a
  BuildKit cache mount in an image build.
  """

  use Mix.Task

  alias Mix.Tasks.UaInspector.Download
  alias UAInspector.Config

  @requirements ["compile"]

  @app_dir Path.expand("../../../../..", __DIR__)

  @switches [
    attempts: :integer,
    offline: :boolean,
    if_missing: :boolean,
    database: :string
  ]

  @cache_dir_env "ARCHIDEP_UA_INSPECTOR_CACHE_DIR"
  @default_cache_dir "tmp/ua_inspector"
  @default_attempts 3
  @retry_delay 2_000

  # Hackney's own defaults are a 5 second receive timeout and an 8 second
  # connect timeout, which is what makes the stock download fail as often as it
  # does. Set here rather than in the application's configuration because this
  # is a property of the download and not of the running application, and
  # because it lets an image build run this task without carrying `config/`.
  @http_opts [connect_timeout: 10_000, recv_timeout: 30_000]

  # Written by the download once every file has been fetched, which is what
  # makes it the mark of a complete copy rather than an interrupted one.
  @release_file "ua_inspector.release"

  @impl Mix.Task
  def run(args) do
    {opts, [], []} = OptionParser.parse(args, strict: @switches)

    database_dir = Keyword.get_lazy(opts, :database, &Config.database_path/0)
    cache_dir = cache_dir()
    current_dir = Path.join(cache_dir, "current")

    cond do
      Keyword.get(opts, :if_missing, false) and complete?(database_dir) ->
        Mix.shell().info("The user agent database is already in #{database_dir}.")

      Keyword.get(opts, :offline, false) ->
        restore!(current_dir, database_dir, "Not downloading the user agent database")

      true ->
        download(opts, cache_dir, current_dir, database_dir)
    end
  end

  defp download(opts, cache_dir, current_dir, database_dir) do
    staging_dir = Path.join(cache_dir, "staging")
    attempts = Keyword.get(opts, :attempts, @default_attempts)

    previous_database_path = Application.fetch_env(:ua_inspector, :database_path)
    previous_http_opts = Application.fetch_env(:ua_inspector, :http_opts)

    Application.put_env(:ua_inspector, :database_path, staging_dir)
    Application.put_env(:ua_inspector, :http_opts, @http_opts)

    result =
      try do
        attempt(staging_dir, attempts)
      after
        reset_env(:database_path, previous_database_path)
        reset_env(:http_opts, previous_http_opts)
      end

    case result do
      :ok ->
        promote!(staging_dir, current_dir)
        copy!(current_dir, database_dir)
        Mix.shell().info("Downloaded the user agent database to #{database_dir}.")

      {:error, message} ->
        File.rm_rf!(staging_dir)

        restore!(
          current_dir,
          database_dir,
          "Could not download the user agent database: #{message}"
        )
    end
  end

  defp attempt(staging_dir, attempts_left) do
    File.rm_rf!(staging_dir)
    File.mkdir_p!(staging_dir)

    case try_downloading() do
      :ok ->
        :ok

      {:error, message} when attempts_left <= 1 ->
        {:error, message}

      {:error, message} ->
        Mix.shell().error("The user agent database download failed (#{message}), trying again...")

        Process.sleep(@retry_delay)
        attempt(staging_dir, attempts_left - 1)
    end
  end

  # `Download` here is `mix ua_inspector.download`, the task this one wraps.
  # `--no-compile` matters: it hands its own arguments to `mix compile`, where
  # `--force` would mean recompiling the whole application.
  defp try_downloading do
    Download.run(["--force", "--quiet", "--no-compile"])
    :ok
  rescue
    error -> {:error, one_line(Exception.message(error))}
  catch
    :exit, reason -> {:error, "exited with #{inspect(reason)}"}
  end

  # The download fails with a `MatchError` whose message spans several lines,
  # which reads badly in the middle of a sentence.
  defp one_line(message), do: message |> String.replace(~r/\s+/, " ") |> String.trim()

  defp restore!(current_dir, database_dir, why) do
    if complete?(current_dir) do
      copy!(current_dir, database_dir)
      Mix.shell().error("#{why}. Using the last copy that worked, from #{current_dir}.")
    else
      Mix.raise("#{why}, and there is no cached copy in #{current_dir} to fall back on.")
    end
  end

  defp promote!(staging_dir, current_dir) do
    File.mkdir_p!(Path.dirname(current_dir))
    File.rm_rf!(current_dir)
    File.rename!(staging_dir, current_dir)
  end

  # Copied file by file rather than with `File.cp_r!/2` because the destination
  # is the database directory itself, which Mix builds as a symbolic link into
  # the dependency: removing or replacing it would break the link.
  defp copy!(from_dir, to_dir) do
    File.mkdir_p!(to_dir)

    Enum.each(File.ls!(from_dir), fn name ->
      File.cp!(Path.join(from_dir, name), Path.join(to_dir, name))
    end)
  end

  defp complete?(dir), do: dir |> Path.join(@release_file) |> File.regular?()

  defp cache_dir do
    case System.get_env(@cache_dir_env) do
      nil -> Path.join(@app_dir, @default_cache_dir)
      "" -> Path.join(@app_dir, @default_cache_dir)
      dir -> Path.expand(dir)
    end
  end

  defp reset_env(key, :error), do: Application.delete_env(:ua_inspector, key)
  defp reset_env(key, {:ok, value}), do: Application.put_env(:ua_inspector, key, value)
end
