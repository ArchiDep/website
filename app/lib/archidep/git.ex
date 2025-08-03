defmodule ArchiDep.Git do
  @moduledoc """
  Holder of Git metadata about the application (currently the current Git
  revision), retrieved and baked in at compile time.
  """

  require Logger

  @git_branch System.get_env("ARCHIDEP_GIT_BRANCH") ||
                if(File.exists?(".git-branch"),
                  do:
                    ".git-branch"
                    |> File.read!()
                    |> String.trim()
                    |> then(fn
                      "" -> "HEAD"
                      branch -> branch
                    end),
                  else: nil
                ) ||
                (case(System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], env: %{})) do
                   {branch, 0} -> String.trim(branch)
                 end)

  @git_dirty System.get_env("ARCHIDEP_GIT_DIRTY") ||
               if(File.exists?(".git-dirty"),
                 do: ".git-dirty" |> File.read!() |> String.trim() != "",
                 else:
                   case(System.cmd("git", ["status", "--porcelain"], env: %{})) do
                     {status, 0} -> String.trim(status) != ""
                   end
               )

  @git_ref System.get_env("ARCHIDEP_GIT_REF")

  @git_revision System.get_env("ARCHIDEP_GIT_REVISION") ||
                  if(File.exists?(".git-revision"),
                    do: ".git-revision" |> File.read!() |> String.trim(),
                    else: nil
                  ) ||
                  (case(System.cmd("git", ["rev-parse", "HEAD"], env: %{})) do
                     {revision, 0} -> String.trim(revision)
                   end)

  @spec start() :: :ok
  def start do
    ref = if @git_ref, do: inspect(@git_ref), else: "<none>"

    Logger.info(~s"""
    Git metadata
    /
    |-> Branch: #{inspect(@git_branch)}
    |-> Dirty: #{inspect(@git_dirty)}
    |-> Ref: #{ref}
    \\-> Revision: #{inspect(@git_revision)}
    """)
  end

  @spec git_branch() :: String.t()
  def git_branch, do: @git_branch

  @spec git_dirty?() :: boolean()
  def git_dirty?, do: @git_dirty

  @spec git_ref() :: String.t() | nil
  def git_ref, do: @git_ref

  @spec git_revision() :: String.t()
  def git_revision, do: @git_revision

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?,
    do:
      @git_branch !=
        (System.get_env("ARCHIDEP_GIT_BRANCH") ||
           if(File.exists?(".git-branch"),
             do:
               ".git-branch"
               |> File.read!()
               |> String.trim()
               |> then(fn
                 "" -> "HEAD"
                 branch -> branch
               end),
             else: nil
           ) ||
           (case(System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], env: %{})) do
              {branch, 0} -> String.trim(branch)
            end)) ||
        @git_dirty !=
          (System.get_env("ARCHIDEP_GIT_DIRTY") ||
             if(File.exists?(".git-dirty"),
               do: ".git-dirty" |> File.read!() |> String.trim() != "",
               else:
                 case(System.cmd("git", ["status", "--porcelain"], env: %{})) do
                   {status, 0} -> String.trim(status) != ""
                 end
             )) ||
        @git_ref != System.get_env("ARCHIDEP_GIT_REF") ||
        @git_revision !=
          (System.get_env("ARCHIDEP_GIT_REVISION") ||
             if(File.exists?(".git-revision"),
               do: ".git-revision" |> File.read!() |> String.trim(),
               else: nil
             ) ||
             (case(System.cmd("git", ["rev-parse", "HEAD"], env: %{})) do
                {revision, 0} -> String.trim(revision)
                _anything_else -> "unknown"
              end))
end
