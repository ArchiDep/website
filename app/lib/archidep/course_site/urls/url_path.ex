defmodule ArchiDep.CourseSite.Urls.UrlPath do
  @moduledoc """
  Path arithmetic on URL paths, used to assemble the URLs emitted by
  `ArchiDep.CourseSite.Urls`.

  Elixir's `Path` module is meant for filesystem paths: it uses the platform's
  separator, and `Path.expand/1` clamps `..` at the root instead of reporting
  it. A URL path always uses `/` and a `..` that escapes the site root is a
  mistake worth surfacing, so these few operations are implemented here rather
  than delegated.
  """

  @doc """
  Join a directory and a relative path. The directory must end with a slash,
  which is the shape of every page URL emitted by
  `ArchiDep.CourseSite.PageRef.output_path/1`.

      iex> UrlPath.join("/course/101-command-line/", "images/cli.jpg")
      "/course/101-command-line/images/cli.jpg"

      iex> UrlPath.join("/course/401-cloud-computing/slides/", "../images/vm.png")
      "/course/401-cloud-computing/slides/../images/vm.png"

      iex> UrlPath.join("images/", "")
      "images/"
  """
  @spec join(String.t(), String.t()) :: String.t()
  def join(dir, path) when is_binary(dir) and is_binary(path), do: dir <> path

  @doc """
  Resolve the `.` and `..` segments of an absolute path. Returns
  `{:error, :escapes_root}` when the path climbs above the root rather than
  silently clamping there, since such a reference cannot resolve to anything in
  the built site.

      iex> UrlPath.normalize("/course/401-cloud-computing/slides/../images/vm.png")
      {:ok, "/course/401-cloud-computing/images/vm.png"}

      iex> UrlPath.normalize("/course/101-command-line/./images/cli.jpg")
      {:ok, "/course/101-command-line/images/cli.jpg"}

      iex> UrlPath.normalize("/course/../../images/cli.jpg")
      {:error, :escapes_root}

      iex> UrlPath.normalize("/course/101-command-line/")
      {:ok, "/course/101-command-line/"}
  """
  @spec normalize(String.t()) :: {:ok, String.t()} | {:error, :escapes_root}
  def normalize("/" <> path) do
    segments = String.split(path, "/")
    trailing_slash? = List.last(segments) in ["", ".", ".."]

    case resolve_segments(segments, []) do
      {:ok, resolved} -> {:ok, "/" <> format_segments(resolved, trailing_slash?)}
      {:error, :escapes_root} = error -> error
    end
  end

  @doc """
  The directory part of a relative path, including its trailing slash, or an
  empty string when the path is a bare filename.

      iex> UrlPath.dirname("images/cli.jpg")
      "images/"

      iex> UrlPath.dirname("../images/vm.png")
      "../images/"

      iex> UrlPath.dirname("cli.jpg")
      ""
  """
  @spec dirname(String.t()) :: String.t()
  def dirname(path) when is_binary(path) do
    case String.split(path, "/") do
      [_basename] -> ""
      segments -> segments |> Enum.drop(-1) |> Enum.join("/") |> Kernel.<>("/")
    end
  end

  @doc """
  Percent-encode a path, leaving its separators intact. Generated PDFs are named
  after course documents and their names contain spaces.

      iex> UrlPath.encode("pdf/ArchiDep 103 - Hello Shell.pdf")
      "pdf/ArchiDep%20103%20-%20Hello%20Shell.pdf"

      iex> UrlPath.encode("images/cli.jpg")
      "images/cli.jpg"
  """
  @spec encode(String.t()) :: String.t()
  def encode(path) when is_binary(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
  end

  @doc """
  Insert a suffix before a filename's extension. Used to name the search assets
  after the build that produced them.

      iex> UrlPath.insert_suffix("lunr.json", "abc123")
      "lunr-abc123.json"

      iex> UrlPath.insert_suffix("search", "abc123")
      "search-abc123"

      iex> UrlPath.insert_suffix("archive.tar.gz", "abc123")
      "archive.tar-abc123.gz"
  """
  @spec insert_suffix(String.t(), String.t()) :: String.t()
  def insert_suffix(filename, suffix) when is_binary(filename) and is_binary(suffix) do
    case Path.extname(filename) do
      "" -> "#{filename}-#{suffix}"
      extension -> "#{Path.rootname(filename)}-#{suffix}#{extension}"
    end
  end

  defp resolve_segments([], resolved), do: {:ok, Enum.reverse(resolved)}
  defp resolve_segments(["" | rest], resolved), do: resolve_segments(rest, resolved)
  defp resolve_segments(["." | rest], resolved), do: resolve_segments(rest, resolved)
  defp resolve_segments([".." | _rest], []), do: {:error, :escapes_root}

  defp resolve_segments([".." | rest], [_parent | resolved]),
    do: resolve_segments(rest, resolved)

  defp resolve_segments([segment | rest], resolved),
    do: resolve_segments(rest, [segment | resolved])

  defp format_segments(segments, false), do: Enum.join(segments, "/")
  defp format_segments([], true), do: ""
  defp format_segments(segments, true), do: Enum.join(segments, "/") <> "/"
end
