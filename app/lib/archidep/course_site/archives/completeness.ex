defmodule ArchiDep.CourseSite.Archives.Completeness do
  @moduledoc """
  Whether a host holds every archived edition it is supposed to serve.

  A deployment renders one edition and keeps the finished ones beside it,
  fetched from the repository they are published in. Nothing about that
  arrangement fails loudly on its own: a fetch that could not reach the
  repository, a clone missing a year, a volume that was never mounted all leave
  a host serving its own edition perfectly and answering 404 for the
  permanently-redirected paths of every earlier one. This is the check that says
  so.

  It is deliberately **not** a reason to refuse to boot, at either level. The
  application serves none of these bytes, so refusing would trade the dashboard,
  the admin console and the servers pipeline for a dead link; and the fetch
  cannot fail hard either, or one first boot with the repository unreachable
  would take the whole site down to protect an edition nobody is being taught.
  So both start, and this is what reports.

  ## The edition being rendered is not checked

  The archive repository holds the current edition too — its directory there
  *is* the backup copy — so a host's clone always contains a second copy of the
  edition that host renders itself. That is expected and permanent, not a
  finding of any kind: those pages are served from the build, first, so whatever
  the clone holds for that year cannot affect what a reader gets. The edition
  being rendered is therefore left out of the check entirely, including when the
  clone holds nothing for it at all.

  ## What "must hold" means

  The editions are a compiled fact of `ArchiDep.CourseSite.Archives` rather than
  configuration — one `course/archives/<year>.json` per finished edition — and
  so are the pages of each. This checks every one of them: the same manifest
  entries the `/latest` resolver matches against, so a half-synced edition is
  caught rather than only a wholly absent one.
  """

  require Logger

  @page_file "index.html"

  @enforce_keys [:directory, :rendered_edition, :expected, :missing]
  defstruct [:directory, :rendered_edition, :expected, :missing]

  @type directory :: :unconfigured | {:missing, Path.t()} | {:present, Path.t()}

  @type t :: %__MODULE__{
          directory: directory(),
          rendered_edition: String.t() | nil,
          expected: [String.t()],
          missing: %{String.t() => nonempty_list(String.t())}
        }

  @doc """
  Which of the editions a host must hold are not where they should be.

  `editions` is what every archived edition published, keyed by the edition, and
  `rendered` is the edition this deployment renders itself, which is excluded
  for the reason the module documents. A page is a directory holding an
  `index.html`, so that is what is looked for.
  """
  @spec check(Path.t() | nil, %{String.t() => [String.t()]}, String.t() | nil) :: t()
  def check(directory, editions, rendered) when is_map(editions) do
    expected = editions |> Map.delete(rendered) |> Map.keys() |> Enum.sort()
    where = directory(directory)

    %__MODULE__{
      directory: where,
      rendered_edition: rendered,
      expected: expected,
      missing: missing(where, editions, expected)
    }
  end

  @doc """
  Whether every edition this host must hold is there.

  A host with nothing to hold is complete, which is what a deployment of the
  first edition is: the one edition archived is the one it renders.
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{expected: []}), do: true
  def complete?(%__MODULE__{directory: {:present, _dir}, missing: missing}), do: missing == %{}
  def complete?(%__MODULE__{}), do: false

  @doc """
  What is wrong with what this host holds, one sentence per problem, empty when
  there is nothing to say.
  """
  @spec problems(t()) :: [String.t()]
  def problems(%__MODULE__{expected: []}), do: []

  def problems(%__MODULE__{directory: :unconfigured, expected: expected}),
    do: ["#{editions(expected)} must be served from this host, which has no archives directory"]

  def problems(%__MODULE__{directory: {:missing, dir}, expected: expected}),
    do: ["#{editions(expected)} must be served from #{dir}, which does not exist"]

  def problems(%__MODULE__{directory: {:present, dir}, expected: expected, missing: missing}),
    do: Enum.flat_map(expected, &problem(&1, missing, dir))

  @doc """
  The one-line answer to whether this host is complete, for a reader who wants
  the answer rather than the details.
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = completeness) do
    case problems(completeness) do
      [] -> held(completeness)
      problems -> Enum.join(problems, "; ")
    end
  end

  @doc """
  Report what this host does not hold.

  Nothing is logged when there is nothing wrong: a line saying an expected state
  holds, on every boot, is what makes the lines that matter unreadable.
  """
  @spec log(t()) :: :ok

  # A deployment that does not say where the editions are kept is not one that
  # claims to hold them — a checkout, or the test environment, whose edition is
  # a year that never happened. Nothing is deployed that way: production states
  # the path, so what can go wrong there is the directory not being there, which
  # is the clause below. The admin console still says so.
  def log(%__MODULE__{directory: :unconfigured}), do: :ok

  def log(%__MODULE__{} = completeness),
    do: Enum.each(problems(completeness), &Logger.error/1)

  defp directory(nil), do: :unconfigured

  defp directory(dir),
    do: if(File.dir?(dir), do: {:present, dir}, else: {:missing, dir})

  defp missing({:present, dir}, editions, expected),
    do:
      expected
      |> Enum.map(&{&1, editions |> Map.fetch!(&1) |> Enum.reject(fn p -> page?(dir, p) end)})
      |> Enum.reject(fn {_edition, absent} -> absent == [] end)
      |> Map.new()

  defp missing(_where, _editions, _expected), do: %{}

  defp page?(dir, path), do: dir |> Path.join(path) |> Path.join(@page_file) |> File.regular?()

  defp problem(edition, missing, dir) do
    case Map.fetch(missing, edition) do
      :error ->
        []

      {:ok, absent} ->
        ["Edition #{edition} is missing #{pages(absent)} from #{dir}: #{listed(absent)}"]
    end
  end

  defp held(%__MODULE__{expected: []}), do: "no edition to hold"

  defp held(%__MODULE__{expected: expected}), do: "#{editions(expected)} held"

  defp editions([edition]), do: "Edition #{edition}"

  defp editions(editions), do: "Editions #{Enum.join(editions, ", ")}"

  defp pages([_page]), do: "1 page"

  defp pages(pages), do: "#{length(pages)} pages"

  # Enough to recognise which edition and which corner of it, without a whole
  # absent edition writing sixty lines nobody reads to the end of.
  defp listed(absent) when length(absent) <= 3, do: Enum.join(absent, ", ")

  defp listed(absent),
    do: "#{absent |> Enum.take(3) |> Enum.join(", ")} and #{length(absent) - 3} more"
end
