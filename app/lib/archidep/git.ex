defmodule ArchiDep.Git do
  @moduledoc """
  Holder of Git metadata about the application (currently the current Git
  revision), retrieved and baked in at compile time.
  """

  alias ArchiDep.Helpers.GitHelpers
  require Logger

  @git_branch GitHelpers.determine_git_branch()
  @git_dirty GitHelpers.determine_git_dirty()
  @git_ref System.get_env("ARCHIDEP_GIT_REF")
  @git_revision GitHelpers.determine_git_revision()

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
        GitHelpers.determine_git_branch() ||
        @git_dirty != GitHelpers.determine_git_dirty() ||
        @git_ref != System.get_env("ARCHIDEP_GIT_REF") ||
        @git_revision != GitHelpers.determine_git_revision()
end
