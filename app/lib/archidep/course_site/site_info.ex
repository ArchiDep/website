defmodule ArchiDep.CourseSite.SiteInfo do
  @moduledoc """
  What a build says about itself: which edition of the course it is, which
  version of the application produced it, and from which commit.

  No document of the course declares any of this and no rule of the subsystem
  derives it — it is a fact about the checkout a build was run from and the year
  it was run for, so the caller states it and the chrome shows it in the footer
  and in what a page prints as. Keeping it a value passed in rather than
  something read here is what lets a build be a function of its inputs like the
  rest of the subsystem: `ArchiDep.CourseSite.Build` is where the bytes come
  from.

  The edition is written twice because it is read in two places that have room
  for different amounts of it: a printed page carries the whole of it, and the
  corner of a slide carries as little as still says which year this is.
  """

  @enforce_keys [:version, :git_branch, :git_revision, :years, :years_short]
  defstruct [:version, :git_branch, :git_revision, :years, :years_short]

  @type t :: %__MODULE__{
          version: String.t(),
          git_branch: String.t() | nil,
          git_revision: String.t() | nil,
          years: String.t(),
          years_short: String.t()
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
  - `:years` (required) — the academic year this edition covers, written out.
  - `:years_short` (required) — the same year with only as much of it as fits in
    the corner of a slide.

  A checkout that cannot name its branch or its revision is a fact rather than a
  failure — a source tarball has neither — so those are `nil` and whatever shows
  them leaves them out.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      version: required!(opts, :version),
      git_branch: optional!(opts, :git_branch),
      git_revision: optional!(opts, :git_revision),
      years: required!(opts, :years),
      years_short: required!(opts, :years_short)
    }
  end

  defp required!(opts, key) do
    case Keyword.fetch!(opts, key) do
      value when is_binary(value) and value != "" ->
        value

      other ->
        raise ArgumentError, "#{key} must be a non-empty string, got: #{inspect(other)}"
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
