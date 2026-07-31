defmodule ArchiDep.CourseSite.SiteInfo do
  @moduledoc """
  What a build says about itself: which version of the application produced it,
  and from which commit.

  No document of the course declares any of this and no rule of the subsystem
  derives it — it is a fact about the checkout a build was run from, so the
  caller states it and the layout shows it in the footer. Keeping it a value
  passed in rather than something read here is what lets a build be a function
  of its inputs like the rest of the subsystem: `ArchiDep.CourseSite.Build` is
  where the bytes come from.
  """

  @enforce_keys [:version, :git_branch, :git_revision]
  defstruct [:version, :git_branch, :git_revision]

  @type t :: %__MODULE__{
          version: String.t(),
          git_branch: String.t() | nil,
          git_revision: String.t() | nil
        }

  @doc """
  State what a build was produced from, raising an `ArgumentError` when a value
  is malformed.

  Options:

  - `:version` (required) — the version of the application, as its `mix.exs`
    declares it.
  - `:git_branch` — the branch the checkout was on, or `nil` when it cannot say.
  - `:git_revision` — the commit the checkout was at, or `nil` when it cannot
    say.

  A checkout that cannot name its branch or its revision is a fact rather than a
  failure — a source tarball has neither — so those are `nil` and whatever shows
  them leaves them out.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      version: version!(opts),
      git_branch: optional!(opts, :git_branch),
      git_revision: optional!(opts, :git_revision)
    }
  end

  defp version!(opts) do
    case Keyword.fetch!(opts, :version) do
      version when is_binary(version) and version != "" ->
        version

      other ->
        raise ArgumentError, "Version must be a non-empty string, got: #{inspect(other)}"
    end
  end

  defp optional!(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        nil

      value when is_binary(value) and value != "" ->
        value

      other ->
        raise ArgumentError,
              "#{key} must be a non-empty string or nil, got: #{inspect(other)}"
    end
  end
end
