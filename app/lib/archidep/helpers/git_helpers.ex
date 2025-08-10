defmodule ArchiDep.Helpers.GitHelpers do
  @moduledoc """
  Helper functions for retrieving Git metadata, used at compile time (see
  `ArchiDep.Git`).
  """

  @git_dir System.get_env("ARCHIDEP_GIT_CWD") || "."

  @spec determine_git_branch() :: String.t()
  def determine_git_branch,
    do:
      git_branch_from_environment() ||
        git_branch_from_file() ||
        git_branch_from_repository()

  @spec determine_git_dirty() :: boolean()
  def determine_git_dirty do
    case git_dirty_from_environment() || git_dirty_from_file() do
      nil -> git_dirty_from_repository()
      dirty when is_boolean(dirty) -> dirty
    end
  end

  @spec determine_git_revision() :: String.t() | nil
  def determine_git_revision,
    do:
      git_revision_from_environment() ||
        git_revision_from_file() ||
        git_revision_from_repository()

  defp git_branch_from_environment, do: System.get_env("ARCHIDEP_GIT_BRANCH")

  defp git_branch_from_file do
    if File.exists?(".git-branch") do
      case ".git-branch"
           |> File.read!()
           |> String.trim() do
        "" -> "HEAD"
        branch when is_binary(branch) -> branch
      end
    else
      nil
    end
  end

  defp git_branch_from_repository do
    {branch, 0} = System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], cd: @git_dir, env: %{})
    String.trim(branch)
  end

  defp git_dirty_from_environment do
    case System.get_env("ARCHIDEP_GIT_DIRTY") do
      nil -> nil
      _value -> true
    end
  end

  defp git_dirty_from_file do
    if File.exists?(".git-dirty") do
      ".git-dirty"
      |> File.read!()
      |> String.trim() != ""
    else
      nil
    end
  end

  defp git_dirty_from_repository do
    {status, 0} = System.cmd("git", ["status", "--porcelain"], cd: @git_dir, env: %{})
    String.trim(status) != ""
  end

  defp git_revision_from_environment, do: System.get_env("ARCHIDEP_GIT_REVISION")

  defp git_revision_from_file do
    if File.exists?(".git-revision") do
      ".git-revision"
      |> File.read!()
      |> String.trim()
    else
      nil
    end
  end

  defp git_revision_from_repository do
    {revision, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: @git_dir, env: %{})
    String.trim(revision)
  end
end
