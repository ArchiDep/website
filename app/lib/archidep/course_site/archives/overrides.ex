defmodule ArchiDep.CourseSite.Archives.Overrides do
  @moduledoc """
  What the course says has become of the pages of its past editions that the
  current one no longer answers for by itself.

  Most archived pages need no entry here: a chapter that kept its slug is
  matched automatically, so renumbering costs nothing and the yearly cost of the
  whole mechanism is the **diff** — the handful of pages renamed or dropped
  since. An entry names one of those, either as the page of the current edition
  that superseded it or as `gone`.

  Declaring a page `gone` is deliberately as much work as redirecting it.
  Nothing may fall back to the home page on its own: were that automatic, one
  rename would silently degrade every archived year's links and the whole table
  would decay into "everything points at the home page" with nobody noticing. So
  a page that matches nothing and is declared nothing fails the build, which is
  what keeps this file honest.

  Both sides of an entry are paths. The left is an archived page's path, opaque
  and matched literally against that year's
  `ArchiDep.CourseSite.Archives.Manifest`; the right is a page of the *current*
  edition, checked against it, so renaming the target is a compilation failure
  naming this entry rather than a link that quietly stops working.
  """

  @year_regex ~r/\A\d{4}\z/
  @gone "gone"

  @enforce_keys [:editions]
  defstruct [:editions]

  @type target :: {:page, String.t()} | :gone

  @type t :: %__MODULE__{
          editions: %{String.t() => %{String.t() => target()}}
        }

  @type error ::
          {:malformed_overrides, String.t()}
          | {:malformed_edition, term()}
          | {:duplicate_edition, String.t()}
          | {:malformed_entries, String.t(), term()}
          | {:malformed_source, String.t(), term()}
          | {:malformed_target, String.t(), String.t(), term()}

  @doc """
  The overrides a decoded `course/_data/archives.yml` declares.

  A year is written unquoted in YAML and therefore read as a number, so both
  forms are accepted and answer to the same edition.

      iex> Overrides.from_yaml(%{2025 => %{"/course/104-ssh/" => "/course/106-secure-shell/"}})
      {:ok, %Overrides{editions: %{"2025" => %{"/course/104-ssh/" => {:page, "/course/106-secure-shell/"}}}}}

      iex> Overrides.from_yaml(%{"2025" => %{"/cheatsheets/unix/" => "gone"}})
      {:ok, %Overrides{editions: %{"2025" => %{"/cheatsheets/unix/" => :gone}}}}

      iex> Overrides.from_yaml(%{})
      {:ok, %Overrides{editions: %{}}}
  """
  @spec from_yaml(term()) :: {:ok, t()} | {:error, nonempty_list(error())}
  def from_yaml(nil), do: {:ok, %__MODULE__{editions: %{}}}

  def from_yaml(overrides) when is_map(overrides) do
    {editions, errors} =
      overrides
      |> Enum.sort_by(&edition_order/1)
      |> Enum.reduce({%{}, []}, &decode_edition/2)

    case Enum.reverse(errors) do
      [] -> {:ok, %__MODULE__{editions: editions}}
      [_first | _rest] = errors -> {:error, errors}
    end
  end

  def from_yaml(overrides),
    do: {:error, [{:malformed_overrides, "#{inspect(overrides)} is not a map of editions"}]}

  @doc """
  The editions this table declares anything about.
  """
  @spec editions(t()) :: [String.t()]
  def editions(%__MODULE__{editions: editions}), do: editions |> Map.keys() |> Enum.sort()

  @doc """
  What an edition declares about each of the pages it names.
  """
  @spec entries(t(), String.t()) :: %{String.t() => target()}
  def entries(%__MODULE__{editions: editions}, edition) when is_binary(edition),
    do: Map.get(editions, edition, %{})

  @doc """
  Describe what is wrong with the overrides.
  """
  @spec format_error(error()) :: String.t()
  def format_error({:malformed_overrides, why}), do: "The archive overrides are invalid: #{why}"

  def format_error({:malformed_edition, edition}),
    do: "The archive overrides declare #{inspect(edition)}, which is not a year"

  def format_error({:duplicate_edition, edition}),
    do: "The archive overrides declare edition #{edition} twice"

  def format_error({:malformed_entries, edition, entries}),
    do: "Edition #{edition} declares #{inspect(entries)} rather than a map of pages"

  def format_error({:malformed_source, edition, source}),
    do: "Edition #{edition} declares #{inspect(source)}, which is not the path of a page"

  def format_error({:malformed_target, edition, source, target}),
    do:
      "Edition #{edition} sends #{inspect(source)} to #{inspect(target)}, which is neither the path of a page nor #{inspect(@gone)}"

  defp decode_edition({edition, entries}, {editions, errors}) do
    case year(edition) do
      {:ok, year} when is_map_key(editions, year) ->
        {editions, [{:duplicate_edition, year} | errors]}

      {:ok, year} ->
        decode_entries(year, entries, {editions, errors})

      :error ->
        {editions, [{:malformed_edition, edition} | errors]}
    end
  end

  defp decode_entries(year, entries, {editions, errors}) when is_map(entries) do
    {decoded, entry_errors} =
      entries
      |> Enum.sort_by(&source_order/1)
      |> Enum.reduce({%{}, errors}, &decode_entry(year, &1, &2))

    {Map.put(editions, year, decoded), entry_errors}
  end

  defp decode_entries(year, entries, {editions, errors}),
    do: {editions, [{:malformed_entries, year, entries} | errors]}

  defp decode_entry(year, {"/" <> _rest = source, target}, {entries, errors}) do
    case target(target) do
      {:ok, decoded} -> {Map.put(entries, source, decoded), errors}
      :error -> {entries, [{:malformed_target, year, source, target} | errors]}
    end
  end

  defp decode_entry(year, {source, _target}, {entries, errors}),
    do: {entries, [{:malformed_source, year, source} | errors]}

  # Read in a fixed order rather than a map's, so that a file with several
  # mistakes in it reports them the same way every run. What is not a year and
  # what is not a page come last, having nowhere to sort among the rest.
  defp edition_order({edition, _entries}) do
    case year(edition) do
      {:ok, year} -> {0, year}
      :error -> {1, inspect(edition)}
    end
  end

  defp source_order({source, _target}) when is_binary(source), do: {0, source}
  defp source_order({source, _target}), do: {1, inspect(source)}

  defp year(edition) when is_integer(edition), do: edition |> Integer.to_string() |> year()

  defp year(edition) when is_binary(edition),
    do: if(Regex.match?(@year_regex, edition), do: {:ok, edition}, else: :error)

  defp year(_edition), do: :error

  defp target(@gone), do: {:ok, :gone}
  defp target("/" <> _rest = path), do: {:ok, {:page, path}}
  defp target(_target), do: :error
end
