defmodule ArchiDep.CourseSite.Renderer.RenderError do
  @moduledoc """
  Something the renderer could not make sense of in one course document: a
  Liquid tag it cannot parse, a link to a document that does not exist, an
  unknown include.

  A document reports **all** of its problems rather than stopping at the first,
  so the author fixes a page in one pass instead of one error per build. That is
  only possible if a tag reports a problem instead of raising, which is why this
  carries the location it happened at and why the whole pipeline threads lists
  of these around.

  It is an exception because `Solid` requires one: a custom filter reports a
  failure as `{:error, exception, fallback}` and `Solid` calls
  `Exception.message/1` on it.
  """

  alias ArchiDep.CourseSite.Urls

  @enforce_keys [:reason, :source_path]
  defexception [:reason, :source_path, :loc]

  @typedoc """
  Where in the source the problem is, in the coordinates of the file on disk
  rather than of the body the renderer works on.
  """
  @type loc :: %{line: pos_integer(), column: pos_integer()}

  @type reason ::
          {:invalid_front_matter, String.t()}
          | :unterminated_front_matter
          | {:liquid, String.t()}
          | {:markdown, String.t()}
          | {:url, Urls.error()}
          | {:invalid_document, String.t()}
          | {:unknown_include, String.t()}
          | {:invalid_tag, tag :: String.t(), String.t()}

  @type t :: %__MODULE__{
          reason: reason(),
          source_path: String.t(),
          loc: loc() | nil
        }

  @doc """
  Build a render error for a document, optionally at a location within it.
  """
  @spec new(reason(), String.t()) :: t()
  @spec new(reason(), String.t(), loc() | nil) :: t()
  def new(reason, source_path, loc \\ nil) when is_binary(source_path),
    do: %__MODULE__{reason: reason, source_path: source_path, loc: normalize(loc)}

  # Solid reports a location as a struct of its own; an error of the renderer is
  # one value however it was produced.
  defp normalize(nil), do: nil
  defp normalize(%{line: line, column: column}), do: %{line: line, column: column}

  @doc """
  Move an error's location down by the number of lines the renderer stripped off
  the top of the file.

  Everything after the front matter is parsed as if it were the whole file, so
  every location the Liquid stage reports is short by exactly the length of the
  front matter. Shifting once, at the end, keeps that arithmetic out of every
  tag.

      iex> RenderError.new({:liquid, "boom"}, "_course/101-command-line/subject.md", %{line: 2, column: 5})
      ...> |> RenderError.shift(4)
      RenderError.new({:liquid, "boom"}, "_course/101-command-line/subject.md", %{line: 6, column: 5})
  """
  @spec shift(t(), non_neg_integer()) :: t()
  def shift(%__MODULE__{loc: nil} = error, _lines), do: error

  def shift(%__MODULE__{loc: %{line: line} = loc} = error, lines)
      when is_integer(lines) and lines >= 0,
      do: %__MODULE__{error | loc: %{loc | line: line + lines}}

  @impl Exception
  def message(%__MODULE__{reason: reason, source_path: source_path, loc: loc}),
    do: "#{describe(reason)} in #{source_path}#{at(loc)}"

  defp at(nil), do: ""
  defp at(%{line: line, column: column}), do: " at line #{line}, column #{column}"

  defp describe({:invalid_front_matter, message}), do: "Invalid front matter (#{message})"

  defp describe(:unterminated_front_matter),
    do: "The front matter is never closed by a line of three dashes"

  defp describe({:liquid, message}), do: message
  defp describe({:markdown, message}), do: "Invalid Markdown (#{message})"
  defp describe({:url, error}), do: Urls.format_error(error)

  defp describe({:invalid_document, path}),
    do: "#{inspect(path)} is not the path of a course document"

  defp describe({:unknown_include, path}), do: "There is no include named #{inspect(path)}"
  defp describe({:invalid_tag, tag, message}), do: "Invalid {% #{tag} %} tag (#{message})"
end
