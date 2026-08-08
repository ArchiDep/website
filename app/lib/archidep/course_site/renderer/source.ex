defmodule ArchiDep.CourseSite.Renderer.Source do
  @moduledoc """
  One course source file, taken apart: its front matter, the body the renderer
  actually renders, and the link reference definitions written at the bottom of
  it.

  The definitions are pulled out because a Markdown renderer only resolves
  `[text][ref]` when it can see the matching `[ref]: url` — and the body is not
  always converted in one piece. A block tag's body is converted on its own, and
  a slide deck is split into sections by reveal.js in the browser, so both need
  the definitions brought back to them. Keeping them here, parsed once per
  document, is what lets that happen without re-scanning the source at every
  use.

  What is kept here is what the **file writes**, which is not always what the
  document means: a destination may itself be Liquid. Expanding it is the
  renderer's job, and `ArchiDep.CourseSite.Renderer.RenderContext` is what
  carries the result — which is why the two functions that put definitions back
  into a fragment take references rather than a source.

  `body_line_offset` is the other reason this module exists: the body is
  rendered as if it were the whole file, so every location an error carries has
  to be moved back down by the length of the front matter to point at the real
  line.
  """

  @enforce_keys [:front_matter, :body, :body_line_offset, :link_references]
  defstruct [:front_matter, :body, :body_line_offset, :link_references]

  @type t :: %__MODULE__{
          front_matter: %{String.t() => term()},
          body: String.t(),
          body_line_offset: non_neg_integer(),
          link_references: [{String.t(), String.t()}]
        }

  @type error :: :unterminated_front_matter | {:invalid_front_matter, String.t()}

  @front_matter_end ~r/^---[ \t]*\r?$/m
  @link_reference ~r/\A\[([^\]]+)\]: ?(.+)\z/

  @doc """
  Take a source file apart.

  Front matter is the YAML block between two lines of three dashes at the very
  top of the file; a file without one is all body.

      iex> Source.parse("---\\ntitle: Command Line\\n---\\n\\nHello.\\n")
      {:ok,
       %Source{
         front_matter: %{"title" => "Command Line"},
         body: "Hello.\\n",
         body_line_offset: 4,
         link_references: []
       }}

      iex> Source.parse("Hello.\\n")
      {:ok, %Source{front_matter: %{}, body: "Hello.\\n", body_line_offset: 0, link_references: []}}

      iex> Source.parse("---\\ntitle: Nope\\n")
      {:error, :unterminated_front_matter}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, error()}
  def parse(source) when is_binary(source) do
    with {:ok, front_matter_source, body, offset} <- split_front_matter(source),
         {:ok, front_matter} <- parse_front_matter(front_matter_source) do
      {:ok,
       %__MODULE__{
         front_matter: front_matter,
         body: body,
         body_line_offset: offset,
         link_references: link_references(body)
       }}
    end
  end

  @doc """
  The `[ref]: url` definitions written at the end of a piece of Markdown.

  Definitions are the run of such lines at the very end, which is where the
  course writes them. One in the middle of a document is left to the Markdown
  renderer, which resolves it for the document but not for a fragment extracted
  from it.

  This is applied to a file by `parse/1` and to those definitions again once
  their Liquid has been expanded, which is what makes the pair of them the same
  reading of the same syntax.

      iex> Source.link_references("Text.\\n\\n[dig]: https://linux.die.net/man/1/dig\\n")
      [{"dig", "https://linux.die.net/man/1/dig"}]

      iex> Source.link_references("Nothing to define.\\n")
      []
  """
  @spec link_references(String.t()) :: [{String.t(), String.t()}]
  def link_references(markdown) when is_binary(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.map(&String.trim/1)
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.take_while(&Regex.match?(@link_reference, &1))
    |> Enum.reverse()
    |> Enum.map(fn line ->
      [_line, name, url] = Regex.run(@link_reference, line)
      {name, String.trim(url)}
    end)
  end

  @doc """
  Link reference definitions as Markdown, ready to be appended to a fragment of
  the document so that a reference link inside it resolves.

      iex> Source.definitions([{"owasp", "https://owasp.org"}])
      "[owasp]: https://owasp.org"

      iex> Source.definitions([])
      ""
  """
  @spec definitions([{String.t(), String.t()}]) :: String.t()
  def definitions(references) when is_list(references),
    do: Enum.map_join(references, "\n", fn {name, url} -> "[#{name}]: #{url}" end)

  @doc """
  Rewrite every reference link in a fragment into an inline link.

  Slides never reach a Markdown renderer here — reveal.js splits the deck into
  sections and converts each one in the browser — so appending the definitions
  once would only serve the last section. Substituting the URL in place is what
  Jekyll does for slides today, and it survives being split anywhere.

      iex> Source.substitute([{"ada", "https://example.com/ada"}], "See [Ada][ada] and [Ada][ada].")
      "See [Ada](https://example.com/ada) and [Ada](https://example.com/ada)."
  """
  @spec substitute([{String.t(), String.t()}], String.t()) :: String.t()
  def substitute(references, markdown) when is_list(references) and is_binary(markdown) do
    Enum.reduce(references, markdown, fn {name, url}, acc ->
      String.replace(acc, "][#{name}]", "](#{url})")
    end)
  end

  defp split_front_matter("---\n" <> rest), do: split_front_matter_end(rest)
  defp split_front_matter("---\r\n" <> rest), do: split_front_matter_end(rest)
  defp split_front_matter(source), do: {:ok, nil, source, 0}

  defp split_front_matter_end(rest) do
    case Regex.split(@front_matter_end, rest, parts: 2) do
      [front_matter, body] ->
        # The two lines of dashes are the offset's other two lines; what follows
        # the closing one starts with that line's own newline rather than with a
        # blank line, so it does not count.
        {blank_lines, body} = body |> strip_line_break() |> trim_leading_blank_lines()
        {:ok, front_matter, body, 2 + count_lines(front_matter) + blank_lines}

      _unterminated ->
        {:error, :unterminated_front_matter}
    end
  end

  defp strip_line_break("\r\n" <> rest), do: rest
  defp strip_line_break("\n" <> rest), do: rest
  defp strip_line_break(body), do: body

  defp trim_leading_blank_lines(body) do
    trimmed = String.replace_leading(body, "\n", "")
    {count_lines(body) - count_lines(trimmed), trimmed}
  end

  defp count_lines(string), do: string |> String.graphemes() |> Enum.count(&(&1 == "\n"))

  defp parse_front_matter(nil), do: {:ok, %{}}

  defp parse_front_matter(source) do
    case YamlElixir.read_from_string(source) do
      {:ok, front_matter} when is_map(front_matter) ->
        {:ok, front_matter}

      {:ok, nil} ->
        {:ok, %{}}

      {:ok, other} ->
        {:error, {:invalid_front_matter, "expected a mapping, got #{inspect(other)}"}}

      {:error, error} ->
        {:error, {:invalid_front_matter, Exception.message(error)}}
    end
  end
end
