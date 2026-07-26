defmodule ArchiDep.CourseSite.Renderer.Highlighter do
  @moduledoc """
  Colours the code blocks of a document.

  Every fenced block becomes the `<pre class="lumis">` that
  [`Lumis`](https://hexdocs.pm/lumis) produces for it, with `l-*` classes the
  theme's two highlighting stylesheets are written against, and the block is
  replaced by that HTML before the document is rendered.

  `Lumis` is called here rather than through MDEx's own syntax highlighting
  because MDEx highlights a block and then splits the HTML it got back on
  newlines to wrap each line in a `<div class="l-line">`, which severs every
  token that spans more than one line — a quarter of the course's fenced blocks,
  a blank line in a shell transcript being the common case. Highlighting a block
  here is also what gives a marked line the `l-highlighted` class the theme
  stylesheets define, rather than the `highlighted` class MDEx asks for and no
  stylesheet styles.

  ## The info string

  What follows the language on the opening fence is a list of [MDEx code block
  decorators](https://mdex.hexdocs.pm/code_block_decorators.html), of which the
  course uses one:

      ```bash highlight_lines="4"

  A block with no language is highlighted as plain text rather than having its
  language guessed, which is what kramdown did for the same fence. An unknown
  language is not an error — `Lumis` falls back to plain text, as Rouge did —
  but a decorator that does not exist is, since that is a typo in a fence the
  author meant to do something.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @plain_text "plaintext"

  # A `key="value"` (or `key=value`) decorator at the start of what is left of
  # the info string, and everything after it.
  @decorator ~r/\A([a-zA-Z_]+)=(?:"([^"]*)"|([^\s"]+))(.*)\z/s

  @doc """
  Replace every code block of a document by its highlighted HTML, reporting the
  fences whose decorators make no sense.

  A fence that cannot be understood is still highlighted, without its
  decorators: the page is worth rendering even when one of its blocks asks for
  something impossible.
  """
  @spec run(MDEx.Document.t(), RenderContext.t()) ::
          {MDEx.Document.t(), [RenderError.t()]}
  def run(%MDEx.Document{} = document, %RenderContext{} = context) do
    highlighted =
      document
      |> Enum.filter(&match?(%MDEx.CodeBlock{}, &1))
      |> Enum.map(&{&1, highlight(&1, context)})

    by_block = Map.new(highlighted)

    document =
      MDEx.Document.update_nodes(document, MDEx.CodeBlock, fn block ->
        {html, _errors} = Map.fetch!(by_block, block)
        %MDEx.HtmlBlock{literal: html}
      end)

    {document, Enum.flat_map(highlighted, fn {_block, {_html, errors}} -> errors end)}
  end

  defp highlight(%MDEx.CodeBlock{info: info, literal: code}, context) do
    {language, rest} = language(info)

    {options, errors} =
      case decorators(rest, []) do
        {:ok, options} ->
          {options, []}

        {:error, message} ->
          {[],
           [
             RenderError.new(
               {:invalid_code_fence, String.trim(info), message},
               context.source_path
             )
           ]}
      end

    html =
      code
      # The literal of a block ends with the newline that closes its last line,
      # which Lumis would otherwise number and show as an empty line of its own.
      |> String.replace_suffix("\n", "")
      |> Lumis.highlight!(formatter: {:html_linked, [language: language] ++ options})

    {html, errors}
  end

  defp language(info) do
    case String.split(String.trim(info), ~r/\s+/, parts: 2) do
      [""] -> {@plain_text, ""}
      [language] -> {language, ""}
      [language, rest] -> {language, rest}
    end
  end

  defp decorators(rest, options) do
    case String.trim_leading(rest) do
      "" -> {:ok, Enum.reverse(options)}
      remaining -> next(remaining, options)
    end
  end

  defp next(remaining, options) do
    with {:ok, option, rest} <- decorator(remaining) do
      decorators(rest, [option | options])
    end
  end

  defp decorator(remaining) do
    case Regex.run(@decorator, remaining) do
      [_match, name, quoted, bare, rest] -> option(name, value(quoted, bare), rest)
      nil -> {:error, ~s(expected `name="value"` decorators after the language)}
    end
  end

  defp value("", bare), do: bare
  defp value(quoted, _bare), do: quoted

  defp option("highlight_lines", value, rest) do
    with {:ok, lines} <- lines(value) do
      {:ok, {:highlight_lines, %{lines: lines}}, rest}
    end
  end

  defp option(name, _value, _rest), do: {:error, "there is no #{inspect(name)} decorator"}

  defp lines(value) do
    value
    |> String.split(",")
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, lines} ->
      case line(String.trim(part)) do
        {:ok, line} -> {:cont, {:ok, lines ++ [line]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp line(part) do
    case String.split(part, "-") do
      [line] -> number(line)
      [first, last] -> range(first, last)
      _more -> {:error, "#{inspect(part)} is neither a line number nor a range of them"}
    end
  end

  defp range(first, last) do
    with {:ok, first} <- number(first),
         {:ok, last} <- number(last) do
      if first <= last do
        {:ok, first..last}
      else
        {:error, "the range of lines #{first}-#{last} ends before it starts"}
      end
    end
  end

  defp number(value) do
    case Integer.parse(value) do
      {number, ""} when number >= 1 -> {:ok, number}
      _other -> {:error, "#{inspect(value)} is not a line number"}
    end
  end
end
