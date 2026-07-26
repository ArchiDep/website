defmodule ArchiDep.CourseSite.Renderer.HeadingIdentifiers do
  @moduledoc """
  Keeps the emoji shortcodes a heading is decorated with out of its identifier.

  A heading's identifier is slugged from its text as it is rendered, so a
  heading written `## :exclamation: Create your server` would be identified by
  `exclamation-create-your-server` — the shortcode named in the anchor the
  course, the application and every reader's bookmark link to. The shortcode is
  decoration: it says the reader has something to do here, and it belongs no
  more in the identifier than the words' capitalisation does.

  A shortcode cannot simply be removed before rendering, because the heading
  still has to show it: it is the sweep of the finished page that turns it into
  an image, along with every other shortcode of the page. So it is moved out of
  the heading's *text* instead — into an inline HTML node, which the renderer
  writes out as it stands and the slugger does not read. What is left to slug is
  the heading as it would have been written without its decoration.

  The shortcode's own trailing space goes with it, or `Create your server` would
  be slugged with the space the shortcode left behind (`-create-your-server`).
  """

  # A shortcode opening the text or standing on its own after a space, with the
  # space that separates it from what follows. Requiring the space is what keeps
  # a heading such as `Meeting at 10:30: what to bring` intact.
  @shortcode ~r/(?<=\A|\s):[a-z0-9_+-]+:[ ]?/
  @only_shortcode ~r/\A:[a-z0-9_+-]+:[ ]?\z/

  @doc """
  Move the emoji shortcodes of every heading of a document out of its text.
  """
  @spec run(MDEx.Document.t()) :: MDEx.Document.t()
  def run(%MDEx.Document{} = document),
    do: MDEx.Document.update_nodes(document, MDEx.Heading, &hide_shortcodes/1)

  defp hide_shortcodes(%MDEx.Heading{nodes: nodes} = heading) do
    hidden = Enum.flat_map(nodes, &split/1)

    if names_the_heading?(hidden) do
      %{heading | nodes: hidden}
    else
      heading
    end
  end

  # A heading of nothing but decoration keeps it: there would otherwise be
  # nothing left to slug, and an identifier nothing can link to.
  defp names_the_heading?(nodes), do: Enum.any?(nodes, &names?/1)

  defp names?(%MDEx.Text{literal: literal}), do: String.trim(literal) != ""
  defp names?(%MDEx.Code{literal: literal}), do: String.trim(literal) != ""
  defp names?(%{nodes: nodes}), do: names_the_heading?(nodes)
  defp names?(_node), do: false

  defp split(%MDEx.Text{literal: literal} = text) do
    if Regex.match?(@shortcode, literal) do
      @shortcode
      |> Regex.split(literal, include_captures: true, trim: true)
      |> Enum.map(&part/1)
    else
      [text]
    end
  end

  defp split(node), do: [node]

  defp part(part) do
    if Regex.match?(@only_shortcode, part) do
      %MDEx.HtmlInline{literal: part}
    else
      %MDEx.Text{literal: part}
    end
  end
end
