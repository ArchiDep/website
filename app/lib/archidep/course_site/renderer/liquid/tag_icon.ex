defmodule ArchiDep.CourseSite.Renderer.Liquid.TagIcon do
  @moduledoc """
  The icon a block tag shows inside its own wrapper.

  A note and a callout both open with one, and it is one of two things: a
  partial of the site's icon set, or one of the site's emoji. They are not the
  same thing said twice — an icon of the set is an SVG the site draws itself,
  and a partial is how the content includes one by hand; an emoji comes from
  `ArchiDep.Emoji`, which is what the rest of the site draws its own from.

  An emoji is written here as the shortcode a page would write, and left at
  that: it is drawn by the sweep of the finished page, which is the one place an
  emoji becomes an image, whoever wrote it. Naming it rather than spelling the
  shortcode out is what makes an emoji the site does not have a broken build
  rather than a page showing `:hammr_and_wrench:` in words.

  An emoji may carry the class of an element to wrap it in, for a tag whose
  theme sizes the icon by its box rather than by the text around it.
  """

  alias ArchiDep.CourseSite.Renderer.Liquid.Partial
  alias ArchiDep.Emoji

  @type t ::
          {:partial, name :: String.t(), class :: String.t()}
          | {:emoji, Emoji.t()}
          | {:emoji, Emoji.t(), class :: String.t()}

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

  def render({:emoji, %Emoji{} = emoji}, %Solid.Context{} = context, _options, _loc),
    do: {Emoji.shortcode(emoji), context}

  def render({:emoji, %Emoji{} = emoji, class}, %Solid.Context{} = context, _options, _loc),
    do: {~s(<div class="#{class}">#{Emoji.shortcode(emoji)}</div>), context}
end
