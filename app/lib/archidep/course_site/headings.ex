defmodule ArchiDep.CourseSite.Headings do
  @moduledoc """
  The headings of a handful of pages, so that a reference to one can be checked.

  A heading's identifier is not written by an author: it is slugged from what
  the heading says while the page is rendered, and a heading a page repeats is
  numbered according to what came before it. So the only way to know that a page
  has a heading is to have rendered it, and this is what holds the answer —
  `ArchiDep.CourseSite.Build.headings!/2` reads it and
  `ArchiDep.CourseSite.Material` looks a heading up while it compiles.

  It holds the pages it was asked about and no others, which is what makes
  `heading!/3` refuse a page and a heading differently: a page that is not in
  here was never read, and that is a mistake in the caller rather than in the
  course.
  """

  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.PageRef

  # How many of a page's own identifiers a failure offers, and how alike one has
  # to be to be worth offering. A heading that has been reworded is the reason
  # this fails, so what the developer needs is the identifier that replaced the
  # one they named.
  @suggestions 3
  @similar_enough 0.7

  @enforce_keys [:pages]
  defstruct [:pages]

  @type t :: %__MODULE__{
          pages: %{PageRef.t() => [String.t()]}
        }

  @doc """
  Hold the identifiers read off each of a set of pages.
  """
  @spec new(%{PageRef.t() => [String.t()]}) :: t()
  def new(pages) when is_map(pages), do: %__MODULE__{pages: pages}

  @doc """
  Look up a heading of a page.
  """
  @spec fetch(t(), PageRef.t(), String.t()) :: {:ok, HeadingRef.t()} | :error
  def fetch(%__MODULE__{pages: pages}, page, id) when is_binary(id) do
    with {:ok, identifiers} <- Map.fetch(pages, page),
         true <- id in identifiers do
      {:ok, HeadingRef.new(page, id)}
    else
      _none -> :error
    end
  end

  @doc """
  Look up a heading of a page, raising when the page does not have it.

  Use this where a missing heading is a stale reference the application wrote
  rather than a fact about the content, as for
  `ArchiDep.CourseSite.Structure.chapter!/3`.
  """
  @spec heading!(t(), PageRef.t(), String.t()) :: HeadingRef.t()
  def heading!(%__MODULE__{pages: pages} = headings, page, id) when is_binary(id) do
    case Map.fetch(pages, page) do
      {:ok, identifiers} -> found!(headings, page, id, identifiers)
      :error -> raise ArgumentError, "No headings were read for #{PageRef.output_path(page)}"
    end
  end

  defp found!(headings, page, id, identifiers) do
    case fetch(headings, page, id) do
      {:ok, heading} ->
        heading

      :error ->
        raise ArgumentError,
              "#{PageRef.output_path(page)} has no #{id} heading#{instead(id, identifiers)}"
    end
  end

  defp instead(id, identifiers) do
    case suggestions(id, identifiers) do
      [] -> ""
      suggestions -> "; did you mean #{Enum.join(suggestions, ", ")}?"
    end
  end

  defp suggestions(id, identifiers),
    do:
      identifiers
      |> Enum.map(&{&1, String.jaro_distance(&1, id)})
      |> Enum.filter(fn {_identifier, distance} -> distance >= @similar_enough end)
      |> Enum.sort_by(fn {_identifier, distance} -> distance end, :desc)
      |> Enum.take(@suggestions)
      |> Enum.map(fn {identifier, _distance} -> identifier end)
end
