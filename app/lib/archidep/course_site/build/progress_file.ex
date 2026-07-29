defmodule ArchiDep.CourseSite.Build.ProgressFile do
  @moduledoc """
  The sessions of the course, read from the one file that records them.

  The file holds them under a `sessions` key, **in the order they were taught**,
  and that order is the file's rather than something derived from the dates: two
  sessions may carry the same date, and one of them recording work the other
  finished is the whole point of the sequence.

  A session may leave a category out, which a course that set no work naturally
  does; every category a session does name has to be a list of numbers, because
  a number that is not one is a chapter this build cannot match against the
  course.
  """

  alias ArchiDep.CourseSite.Session

  @categories [:done, :due, :next]

  @type error ::
          {:malformed_progress, String.t()}
          | {:malformed_session, non_neg_integer(), String.t()}

  @doc """
  The sessions of the course named by a decoded progress file.

      iex> ProgressFile.sessions(%{
      ...>   "sessions" => [
      ...>     %{"date" => "2025-09-19", "title" => "CLI", "done" => [100], "due" => [101]}
      ...>   ]
      ...> })
      {:ok, [%Session{date: ~D[2025-09-19], title: "CLI", done: [100], due: [101], next: []}]}

      iex> ProgressFile.sessions(%{})
      {:error, {:malformed_progress, "no \\"sessions\\" list"}}

      iex> ProgressFile.sessions(%{"sessions" => [%{"title" => "CLI"}]})
      {:error, {:malformed_session, 0, "no \\"date\\""}}
  """
  @spec sessions(map()) :: {:ok, [Session.t()]} | {:error, error()}
  def sessions(%{"sessions" => sessions}) when is_list(sessions) do
    read = sessions |> Enum.with_index() |> Enum.reduce_while([], &session/2)

    case read do
      {:error, _reason} = error -> error
      sessions -> {:ok, Enum.reverse(sessions)}
    end
  end

  def sessions(%{"sessions" => _other}),
    do: {:error, {:malformed_progress, ~s{"sessions" is not a list}}}

  def sessions(decoded) when is_map(decoded),
    do: {:error, {:malformed_progress, ~s{no "sessions" list}}}

  @doc """
  Describe what is wrong with a progress file, for a build that has to report it.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:malformed_progress, why}), do: "The progress file is malformed: #{why}"

  def format_error({:malformed_session, index, why}),
    do: "Session #{index + 1} of the progress file is malformed: #{why}"

  defp session({session, index}, read) when is_map(session) do
    with {:ok, date} <- date(session, index),
         {:ok, title} <- title(session, index),
         {:ok, numbers} <- categories(session, index) do
      {:cont, [Session.new(date, title, numbers.done, numbers.due, numbers.next) | read]}
    else
      {:error, _reason} = error -> {:halt, error}
    end
  end

  defp session({_session, index}, _read),
    do: {:halt, {:error, {:malformed_session, index, "it is not an object"}}}

  defp date(session, index) do
    case Map.fetch(session, "date") do
      {:ok, date} when is_binary(date) -> parsed_date(date, index)
      {:ok, other} -> {:error, {:malformed_session, index, "#{inspect(other)} is not a date"}}
      :error -> {:error, {:malformed_session, index, ~s{no "date"}}}
    end
  end

  defp parsed_date(date, index) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _reason} -> {:error, {:malformed_session, index, "#{inspect(date)} is not a date"}}
    end
  end

  defp title(session, index) do
    case Map.fetch(session, "title") do
      {:ok, title} when is_binary(title) and title != "" -> {:ok, title}
      {:ok, other} -> {:error, {:malformed_session, index, "#{inspect(other)} is not a title"}}
      :error -> {:error, {:malformed_session, index, ~s{no "title"}}}
    end
  end

  defp categories(session, index) do
    Enum.reduce_while(@categories, {:ok, %{}}, fn category, {:ok, numbers} ->
      case category_numbers(session, category, index) do
        {:ok, read} -> {:cont, {:ok, Map.put(numbers, category, read)}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp category_numbers(session, category, index) do
    case Map.get(session, Atom.to_string(category), []) do
      numbers when is_list(numbers) -> chapter_numbers(numbers, category, index)
      other -> {:error, malformed_category(category, other, index)}
    end
  end

  defp chapter_numbers(numbers, category, index) do
    if Enum.all?(numbers, &(is_integer(&1) and &1 > 0)) do
      {:ok, numbers}
    else
      {:error, malformed_category(category, numbers, index)}
    end
  end

  defp malformed_category(category, value, index),
    do:
      {:malformed_session, index,
       ~s("#{category}" is #{inspect(value)} rather than a list of chapter numbers)}
end
