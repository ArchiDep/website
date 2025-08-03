defmodule ArchiDep.Git do
  @moduledoc """
  Holder of Git metadata about the application (currently the current Git
  revision), retrieved and baked in at compile time.
  """

  require Logger

  @git_revision System.get_env("ARCHIDEP_GIT_REVISION") ||
                  if(File.exists?(".revision"), do: File.read!(".revision"), else: nil) ||
                  (case(System.cmd("git", ["rev-parse", "HEAD"], env: %{})) do
                     {revision, 0} -> String.trim(revision)
                   end)

  @spec start() :: :ok
  def start do
    Logger.info(~s"""
    Git metadata
    /
    \\-> Revision: #{inspect(@git_revision)}
    """)
  end

  @spec git_revision() :: String.t()
  def git_revision, do: @git_revision

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?,
    do:
      @git_revision !=
        (System.get_env("ARCHIDEP_GIT_REVISION") ||
           if(File.exists?(".revision"), do: File.read!(".revision"), else: nil) ||
           (case(System.cmd("git", ["rev-parse", "HEAD"], env: %{})) do
              {revision, 0} -> String.trim(revision)
              _anything_else -> "unknown"
            end))
end
