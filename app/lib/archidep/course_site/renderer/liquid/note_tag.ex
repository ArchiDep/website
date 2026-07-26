defmodule ArchiDep.CourseSite.Renderer.Liquid.NoteTag do
  @moduledoc """
  `{% note type: tip %}` — an aside: a box of prose, titled and iconed, that the
  reader may skip without losing the thread of the chapter.

  It is by far the most used tag of the course. Its `type` picks both the icon
  and the title, so writing one is a matter of saying what kind of aside it is;
  `title` overrides the wording when the default is not specific enough.

  Two of the six kinds show an icon of the site's own set and the other four an
  emoji, written here as the shortcode the content itself writes and turned into
  an image later, when the finished page is swept for shortcodes.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.Liquid.TagIcon
  alias ArchiDep.CourseSite.Renderer.RenderError

  @icons %{
    "advanced" => {:literal, ":space_invader:"},
    "info" => {:partial, "info-circle", "size-6"},
    "more" => {:literal, ":books:"},
    "tip" => {:literal, ":gem:"},
    "troubleshooting" => {:literal, ":boom:"},
    "warning" => {:partial, "exclamation-triangle", "size-6"}
  }

  @titles %{
    "advanced" => "Advanced",
    "info" => "Note",
    "more" => "More information",
    "tip" => "Tip",
    "troubleshooting" => "Troubleshooting",
    "warning" => "Warning"
  }

  @default_type "info"

  @enforce_keys [:loc, :type, :title, :icon, :body, :problems]
  defstruct [:loc, :type, :title, :icon, :body, :problems]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          type: String.t(),
          title: String.t(),
          icon: TagIcon.t(),
          body: Solid.Parser.parse_tree(),
          problems: [RenderError.reason()]
        }

  @impl Solid.Tag
  def parse("note", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endnote") do
      {type, problems} = type(attributes)

      {:ok,
       %__MODULE__{
         loc: loc,
         type: type,
         title: title(attributes, type),
         icon: Map.fetch!(@icons, type),
         body: body,
         problems: problems
       }, context}
    end
  end

  # An aside of a kind the site has no icon or title for is shown as the plain
  # note it defaults to, and the kind the author asked for is reported: the page
  # still reads, which is the point of reporting rather than raising.
  defp type(attributes) do
    case Map.get(attributes, "type", @default_type) do
      type when is_map_key(@icons, type) ->
        {type, []}

      unknown ->
        {@default_type, [{:invalid_tag, "note", "Unknown type #{inspect(unknown)}"}]}
    end
  end

  defp title(attributes, type) do
    case attributes |> Map.get("title", "") |> to_string() |> String.trim() do
      "" -> Map.fetch!(@titles, type)
      title -> title
    end
  end

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.Registers

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context!, options) do
      context! = Registers.report(context!, tag.problems, tag.loc)
      {icon, context!} = TagIcon.render(tag.icon, context!, options, tag.loc)
      {body, context!} = NestedBody.to_html(tag.body, context!, options)

      {~s(<div class="note note-#{tag.type}">) <>
         ~s(<div class="title">#{icon}<span>#{tag.title}</span></div>) <>
         ~s(<div class="content">#{body}</div>) <>
         ~s(</div>), context!}
    end
  end
end
