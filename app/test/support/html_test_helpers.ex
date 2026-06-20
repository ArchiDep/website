defmodule ArchiDepWeb.Support.HtmlTestHelpers do
  @moduledoc """
  Helper functions to test HTML views (including live views).

  HTML is parsed and queried with [LazyHTML](https://hexdocs.pm/lazy_html), the
  same engine Phoenix LiveView uses internally for its own test helpers, so the
  application carries a single HTML parser across the test suite.
  """

  defmodule HTMLAssertionError do
    @moduledoc """
    An HTML assertion has failed.
    """

    defexception [:message]
  end

  @type html :: String.t() | LazyHTML.t()

  defguardp is_html(value) when is_binary(value) or is_struct(value, LazyHTML)

  @doc """
  Finds the elements matching a selector in the specified HTML, returning each
  matching element as its own `LazyHTML` document so callers can map over the
  matches and query further within each one.

  ## Examples

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> html = \"""
      ...>   <html>
      ...>     <head></head>
      ...>     <body>
      ...>       <p>Hello</p>
      ...>       <p>World</p>
      ...>     </body>
      ...>   </html>
      ...> \"""
      iex> html |> find_html_elements("p") |> Enum.map(&html_element_text/1)
      ["Hello", "World"]
      iex> find_html_elements(html, "span")
      []
  """
  @spec find_html_elements(html(), String.t()) :: [LazyHTML.t()]
  def find_html_elements(html, selector) when is_html(html) and is_binary(selector),
    do: html |> parse_html() |> LazyHTML.query(selector) |> Enum.to_list()

  @doc """
  Returns the normalized text content of an HTML element: its descendant text
  with internal whitespace runs collapsed to single spaces and surrounding
  whitespace trimmed.

  ## Examples

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> "<p>  Hello   world  </p>" |> find_html_elements("p") |> hd() |> html_element_text()
      "Hello world"
  """
  @spec html_element_text(html()) :: String.t()
  def html_element_text(html) when is_html(html),
    do: html |> parse_html() |> LazyHTML.text() |> normalize_whitespace()

  @doc """
  Returns the value of the given attribute on the first matching HTML element,
  or `nil` if it has no such attribute. A valueless (boolean) attribute reads as
  the empty string.

  ## Examples

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> ~s(<input value="hi" />) |> find_html_elements("input") |> hd() |> html_element_attribute("value")
      "hi"

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> "<input />" |> find_html_elements("input") |> hd() |> html_element_attribute("value")
      nil
  """
  @spec html_element_attribute(html(), String.t()) :: String.t() | nil
  def html_element_attribute(html, name) when is_html(html) and is_binary(name),
    do: html |> parse_html() |> LazyHTML.attribute(name) |> List.first()

  @doc """
  Asserts that the title of an HTML page is as expected, returning the parsed
  document so further assertions can be chained.

  ## Examples

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> html = "<html><head><title>Hello</title></head><body><h1>Hi</h1></body></html>"
      iex> html |> assert_html_title("Hello") |> find_html_elements("h1") |> Enum.map(&html_element_text/1)
      ["Hi"]

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> assert_html_title(
      ...>   "<html><head><title>Hello</title></head><body></body></html>",
      ...>   "World"
      ...> )
      ** (ArchiDepWeb.Support.HtmlTestHelpers.HTMLAssertionError) Expected page title "Hello" to equal "World" in "<html><head><title>Hello</title></head><body></body></html>"
  """
  @spec assert_html_title(html(), String.t()) :: LazyHTML.t()
  def assert_html_title(html, title) when is_html(html) and is_binary(title) do
    doc = parse_html(html)

    actual_title =
      doc
      |> LazyHTML.query("head > title")
      |> LazyHTML.text()
      |> normalize_whitespace()

    unless actual_title == title do
      raise HTMLAssertionError,
            "Expected page title #{inspect(actual_title)} to equal #{inspect(title)} in #{inspect(LazyHTML.to_html(doc, skip_whitespace_nodes: true))}"
    end

    doc
  end

  defp parse_html(html) when is_binary(html), do: LazyHTML.from_document(html)
  defp parse_html(%LazyHTML{} = html), do: html

  defp normalize_whitespace(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()
end
