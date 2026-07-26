defmodule ArchiDep.CourseSite.Renderer.Liquid.TagIcon do
  @moduledoc """
  The icon a block tag shows inside its own wrapper.

  A note and a callout both open with one, and it is written in the tag in one
  of two ways: as a partial of the site's icon set, or as a piece of HTML the
  tag holds itself — an emoji shortcode, or a shortcode already wrapped in the
  element the theme styles.

  A shortcode is left as it is written. It becomes an image when the finished
  page is swept for shortcodes, which cannot happen any earlier: a heading's
  identifier is slugged from its text as it is rendered, and the course links to
  headings named after the emoji in them.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.Partial

  @type t :: {:partial, name :: String.t(), class :: String.t()} | {:literal, String.t()}

  @doc """
  Render an icon into what goes inside the tag's wrapper.

  What comes back carries no whitespace around it, since a blank line would end
  the wrapper's HTML block and leave the rest of the wrapper to be read as
  Markdown.
  """
  @spec render(t(), Solid.Context.t(), keyword(), Solid.Lexer.loc() | nil) ::
          {String.t(), Solid.Context.t()}
  def render({:partial, name, class}, %Solid.Context{} = context, options, loc) do
    {rendered, context} =
      Partial.render("icons/#{name}.html", %{"class" => class}, context, options, loc)

    {rendered |> IO.iodata_to_binary() |> String.trim(), context}
  end

  def render({:literal, html}, %Solid.Context{} = context, _options, _loc), do: {html, context}
end
