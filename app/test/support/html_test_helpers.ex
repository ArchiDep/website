defmodule ArchiDepWeb.Support.HtmlTestHelpers do
  @moduledoc """
  Helper functions to test HTML views (including live views).
  """

  defmodule HTMLAssertionError do
    @moduledoc """
    An HTML assertion has failed.
    """

    defexception [:message]
  end

  @type html :: String.t() | Floki.html_tree()
  @type html_tree :: Floki.html_tree()

  defguardp is_html(value) when is_binary(value) or is_list(value)

  @doc """
  Finds the elements matching a selector in the specified HTML.

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
      iex> parsed_html = Floki.parse_document!(html)
      iex> the_two_paragraphs = Floki.parse_fragment!("<p>Hello</p><p>World</p>")
      iex> find_html_elements(html, "p")
      the_two_paragraphs
      iex> find_html_elements(parsed_html, "p")
      the_two_paragraphs

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
      iex> find_html_elements(html, "span")
      []
  """
  @spec find_html_elements(html, String.t()) :: html_tree
  def find_html_elements(html, selector) when is_html(html) and is_binary(selector),
    do: html |> assert_html() |> Floki.find(selector)

  @doc """
  Asserts that the title of an HTML page is as expected.

  ## Examples

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> html = \"""
      ...>   <html>
      ...>     <head>
      ...>       <title>Hello</title>
      ...>     </head>
      ...>     <body>
      ...>       <h1>Hello</h1>
      ...>     </body>
      ...>   </html>
      ...> \"""
      iex> parsed_html = Floki.parse_document!(html)
      iex> assert_html_title(html, "Hello")
      parsed_html
      iex> assert_html_title(parsed_html, "Hello")
      parsed_html

      iex> import ArchiDepWeb.Support.HtmlTestHelpers
      iex> assert_html_title(
      ...>   \"""
      ...>     <html>
      ...>       <head>
      ...>         <title>Hello</title>
      ...>       </head>
      ...>       <body>
      ...>         <h1>Hello</h1>
      ...>       </body>
      ...>     </html>
      ...>   \""",
      ...>   "World"
      ...> )
      ** (ArchiDepWeb.Support.HtmlTestHelpers.HTMLAssertionError) Expected page title "Hello" to equal "World" in "<html><head><title>Hello</title></head><body><h1>Hello</h1></body></html>"
  """
  @spec assert_html_title(html(), String.t()) :: html_tree()
  def assert_html_title(html, title) when is_html(html) and is_binary(title) do
    doc = assert_html(html)

    actual_title =
      doc
      |> Floki.find("title")
      |> Enum.map(&elem(&1, 2))
      |> List.flatten()
      |> List.first()
      |> String.trim()
      |> String.replace(~r/\s+/, " ")

    unless actual_title == title do
      raise HTMLAssertionError,
            "Expected page title #{inspect(actual_title)} to equal #{inspect(title)} in #{inspect_html(doc)}"
    end

    doc
  end

  defp assert_html(html) when is_list(html), do: html
  defp assert_html(html) when is_binary(html), do: Floki.parse_document!(html)

  defp inspect_html(html) when is_list(html), do: inspect(Floki.raw_html(html))
end
