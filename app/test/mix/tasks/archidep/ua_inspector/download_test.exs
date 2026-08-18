defmodule ArchiDep.Support.UaInspectorStubAdapter do
  @moduledoc """
  A UAInspector download adapter that answers from the test process instead of
  the network, failing the next `n` files for whatever `n` the test put in its
  process dictionary.

  The downloader runs in the process that called the task, which is the test's
  own, so the count is per test and needs nothing to reset it.
  """

  @behaviour UAInspector.Downloader.Adapter

  @failures :ua_inspector_stub_failures

  @doc """
  Fail the next `count` files this adapter is asked for.
  """
  @spec fail_next(non_neg_integer()) :: :ok
  def fail_next(count) do
    Process.put(@failures, count)
    :ok
  end

  @impl UAInspector.Downloader.Adapter
  def read_remote(_location) do
    case Process.get(@failures, 0) do
      0 ->
        {:ok, "stub"}

      failures ->
        Process.put(@failures, failures - 1)
        {:error, :timeout}
    end
  end
end

defmodule Mix.Tasks.Archidep.UaInspector.DownloadTest do
  # `Mix.shell/0`, the application environment and the system environment are
  # all global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias ArchiDep.Support.UaInspectorStubAdapter
  alias Mix.Tasks.Archidep.UaInspector.Download

  @moduletag :tmp_dir

  @cache_dir_env "ARCHIDEP_UA_INSPECTOR_CACHE_DIR"
  @release_file "ua_inspector.release"

  setup :capture_mix_shell

  # Both directories this task writes to are pinned inside the test's own
  # temporary directory, and the downloader is answered from this process: a
  # test can neither reach the network nor touch the database the development
  # environment runs on.
  setup %{tmp_dir: tmp_dir} do
    cache_dir = Path.join(tmp_dir, "cache")
    previous_cache_dir = System.get_env(@cache_dir_env)
    System.put_env(@cache_dir_env, cache_dir)

    previous_adapter = Application.fetch_env(:ua_inspector, :downloader_adapter)
    Application.put_env(:ua_inspector, :downloader_adapter, UaInspectorStubAdapter)

    on_exit(fn ->
      case previous_cache_dir do
        nil -> System.delete_env(@cache_dir_env)
        dir -> System.put_env(@cache_dir_env, dir)
      end

      case previous_adapter do
        :error -> Application.delete_env(:ua_inspector, :downloader_adapter)
        {:ok, adapter} -> Application.put_env(:ua_inspector, :downloader_adapter, adapter)
      end
    end)

    %{
      cache_dir: cache_dir,
      current_dir: Path.join(cache_dir, "current"),
      staging_dir: Path.join(cache_dir, "staging"),
      database_dir: Path.join(tmp_dir, "database")
    }
  end

  describe "run/1" do
    test "leaves a database that is already there alone", ctx do
      database!(ctx.database_dir, "6.5.0")

      Download.run(["--if-missing", "--database", ctx.database_dir])

      assert shell_output() == [
               {:info, "The user agent database is already in #{ctx.database_dir}."}
             ]

      assert File.read!(Path.join(ctx.database_dir, @release_file)) == "6.5.0"
      assert File.exists?(ctx.cache_dir) == false
    end

    test "downloads a database that is not there yet", ctx do
      Download.run(["--if-missing", "--attempts", "1", "--database", ctx.database_dir])

      assert shell_output() == [
               {:info, "Downloaded the user agent database to #{ctx.database_dir}."}
             ]

      assert File.regular?(Path.join(ctx.database_dir, @release_file)) == true
    end

    # A download that got every file becomes the copy the next failure falls
    # back on, and the database and that copy are the same files.
    test "keeps what it downloaded as the copy to fall back on", ctx do
      Download.run(["--attempts", "1", "--database", ctx.database_dir])

      assert shell_output() == [
               {:info, "Downloaded the user agent database to #{ctx.database_dir}."}
             ]

      assert Enum.sort(File.ls!(ctx.database_dir)) == Enum.sort(File.ls!(ctx.current_dir))
      assert File.regular?(Path.join(ctx.current_dir, @release_file)) == true
      assert File.exists?(ctx.staging_dir) == false
    end

    test "restores the cached copy instead of downloading when told it is offline", ctx do
      database!(ctx.current_dir, "6.4.0")

      Download.run(["--offline", "--database", ctx.database_dir])

      assert shell_output() == [
               {:error,
                "Not downloading the user agent database. Using the last copy that worked, from #{ctx.current_dir}."}
             ]

      assert Enum.sort(File.ls!(ctx.database_dir)) == ["bot.bots.yml", @release_file]
      assert File.read!(Path.join(ctx.database_dir, @release_file)) == "6.4.0"
    end

    test "fails when it is offline and nothing has ever downloaded cleanly", ctx do
      assert_raise Mix.Error,
                   "Not downloading the user agent database, and there is no cached copy in #{ctx.current_dir} to fall back on.",
                   fn -> Download.run(["--offline", "--database", ctx.database_dir]) end

      assert shell_output() == []
      assert File.exists?(ctx.database_dir) == false
    end

    test "falls back on the cached copy when the download fails", ctx do
      database!(ctx.current_dir, "6.3.0")
      UaInspectorStubAdapter.fail_next(1)

      Download.run(["--attempts", "1", "--database", ctx.database_dir])

      assert shell_output() == [
               {:error,
                "Could not download the user agent database: no match of right hand side value: {:error, :timeout}. Using the last copy that worked, from #{ctx.current_dir}."}
             ]

      assert File.read!(Path.join(ctx.database_dir, @release_file)) == "6.3.0"
      assert File.exists?(ctx.staging_dir) == false
    end

    test "fails when the download fails and there is nothing to fall back on", ctx do
      UaInspectorStubAdapter.fail_next(1)

      assert_raise Mix.Error,
                   "Could not download the user agent database: no match of right hand side value: {:error, :timeout}, and there is no cached copy in #{ctx.current_dir} to fall back on.",
                   fn -> Download.run(["--attempts", "1", "--database", ctx.database_dir]) end

      assert shell_output() == []
      assert File.exists?(ctx.database_dir) == false
    end

    # One timed-out response is not an answer about the remote, so a failure
    # costs another attempt before it costs the cached copy.
    test "tries again before giving up on a download that failed", ctx do
      UaInspectorStubAdapter.fail_next(1)

      Download.run(["--attempts", "2", "--database", ctx.database_dir])

      assert shell_output() == [
               {:error,
                "The user agent database download failed (no match of right hand side value: {:error, :timeout}), trying again..."},
               {:info, "Downloaded the user agent database to #{ctx.database_dir}."}
             ]

      assert File.regular?(Path.join(ctx.database_dir, @release_file)) == true
    end
  end

  # A database is complete when it holds the release file the download writes
  # once it has every file, which is what tells a whole copy from an interrupted
  # one.
  defp database!(dir, release) do
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, @release_file), release)
    File.write!(Path.join(dir, "bot.bots.yml"), "- regex: 'stub'")
  end
end
