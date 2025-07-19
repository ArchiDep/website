defmodule ArchiDep.Git do
  @moduledoc """
  Holder of Git metadata about the application (currently the current Git
  revision), retrieved and baked in at compile time.
  """

  @git_revision System.get_env("ARCHIDEP_GIT_REVISION") ||
                  (case(System.cmd("git", ["rev-parse", "HEAD"])) do
                     {revision, 0} -> String.trim(revision)
                   end)

  @spec git_revision() :: String.t()
  def git_revision, do: @git_revision

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?,
    do:
      @git_revision !=
        (System.get_env("ARCHIDEP_GIT_REVISION") ||
           (case(System.cmd("git", ["rev-parse", "HEAD"])) do
              {revision, 0} -> String.trim(revision)
              _anything_else -> "unknown"
            end))
end
