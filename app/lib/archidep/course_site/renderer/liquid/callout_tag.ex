defmodule ArchiDep.CourseSite.Renderer.Liquid.CalloutTag do
  @moduledoc """
  `{% callout type: exercise %}` — something the reader must not skip: a step to
  carry out, a warning about what will otherwise go wrong, or a digression the
  page keeps folded until asked.

  A callout of the `more` kind is that last one, and it is the reason this tag
  is the only one that names anything: the fold is a checkbox and a label, which
  find each other by an identifier, so every `more` callout of a page needs one
  of its own. The identifier is written in the tag and the page it is on is
  prefixed to it, so that an author picks a name that is meaningful in a chapter
  rather than one that has to be unique across the whole course.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.Liquid.Registers
  alias ArchiDep.CourseSite.Renderer.Liquid.TagIcon
  alias ArchiDep.CourseSite.Renderer.RenderError

  @icons %{
    "danger" => {:partial, "exclamation-circle", "icon"},
    "exercise" => {:literal, ~s(<div class="icon text">🛠️</div>)},
    "more" => {:literal, ~s(<div class="icon image">:books:</div>)},
    "warning" => {:partial, "exclamation-triangle", "icon"}
  }

  @default_type "danger"
  @folded_type "more"
  @identifier_regex ~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  # What the label that folds a callout back up says. Which one a callout gets
  # is derived from its identifier, so that a page rendered twice is the same
  # page.
  @congratulations [
    "Amazing!",
    "Awesome!",
    "Cool!",
    "Fabulous!",
    "Great!",
    "Outstanding!",
    "Terrific!",
    "Wonderful!"
  ]

  @celebrations ~w(🎉 🎊 🚀 👍 👏 🌟 ✨ 💫 😎)

  @enforce_keys [:loc, :type, :icon, :identifier, :animate?, :body, :problems]
  defstruct [:loc, :type, :icon, :identifier, :animate?, :body, :problems]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          type: String.t(),
          icon: TagIcon.t(),
          identifier: String.t() | nil,
          animate?: boolean(),
          body: Solid.Parser.parse_tree(),
          problems: [RenderError.reason()]
        }

  @impl Solid.Tag
  def parse("callout", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endcallout") do
      {type, type_problems} = type(attributes)
      {identifier, identifier_problems} = identifier(attributes, type)

      {:ok,
       %__MODULE__{
         loc: loc,
         type: type,
         icon: Map.fetch!(@icons, type),
         identifier: identifier,
         animate?: Map.get(attributes, "animate") == "true",
         body: body,
         problems: type_problems ++ identifier_problems
       }, context}
    end
  end

  @doc """
  The name the checkbox of a folded callout and its labels find each other by,
  or nothing for a callout that is not folded and therefore names nothing.

  An identifier the author wrote is taken as it is; one that is missing,
  malformed or already taken by another callout of the same document is replaced
  by a positional one and reported, so that the fold still works while the build
  fails over the name.
  """
  @spec identify(t(), Solid.Context.t()) :: {String.t() | nil, Solid.Context.t()}
  def identify(%__MODULE__{type: @folded_type, identifier: identifier} = tag, context) do
    taken = Registers.identifiers(context)

    identifier =
      if identifier != nil and not MapSet.member?(taken, identifier),
        do: identifier,
        else: positional_identifier(taken, MapSet.size(taken) + 1)

    context = context |> Registers.take_identifier(identifier) |> report_taken(tag, identifier)

    {"#{page_prefix(Registers.fetch!(context).page)}:#{identifier}", context}
  end

  def identify(%__MODULE__{}, %Solid.Context{} = context), do: {nil, context}

  @doc """
  What the label that folds a callout back up says, and the emoji next to it.
  """
  @spec congratulations(String.t()) :: {String.t(), String.t()}
  def congratulations(identifier),
    do: {pick(@celebrations, identifier), pick(@congratulations, identifier)}

  # A callout of a kind the site has no icon for is shown as the plain callout
  # it defaults to, and the kind the author asked for is reported.
  defp type(attributes) do
    case Map.get(attributes, "type", @default_type) do
      type when is_map_key(@icons, type) ->
        {type, []}

      unknown ->
        {@default_type, [{:invalid_tag, "callout", "Unknown type #{inspect(unknown)}"}]}
    end
  end

  # Only a folded callout is named, so an identifier written on any other kind
  # has nothing to name and is ignored.
  defp identifier(attributes, @folded_type) do
    case Map.get(attributes, "id") do
      identifier when is_binary(identifier) ->
        if Regex.match?(@identifier_regex, identifier),
          do: {identifier, []},
          else: {nil, [{:invalid_tag, "callout", malformed(identifier)}]}

      _none ->
        {nil, [{:invalid_tag, "callout", ~s(A "more" callout must have an id)}]}
    end
  end

  defp identifier(_attributes, _type), do: {nil, []}

  defp malformed(identifier),
    do:
      "The id #{inspect(identifier)} must be lowercase alphanumeric words " <>
        "separated by hyphens"

  defp report_taken(context, %__MODULE__{identifier: identifier}, identifier), do: context

  defp report_taken(context, %__MODULE__{identifier: nil}, _identifier), do: context

  defp report_taken(context, %__MODULE__{identifier: identifier} = tag, _fresh),
    do:
      Registers.report(
        context,
        {:invalid_tag, "callout",
         "The id #{inspect(identifier)} is already used in this document"},
        tag.loc
      )

  defp positional_identifier(taken, position) do
    candidate = "callout-#{position}"

    if MapSet.member?(taken, candidate),
      do: positional_identifier(taken, position + 1),
      else: candidate
  end

  # The chapter a callout is in, which is what makes an identifier that is
  # unique in a page enough to be unique on the site.
  defp page_prefix({:document, document}), do: DocumentRef.dir(document)
  defp page_prefix({:cheatsheet, slug}), do: "cheatsheets-#{slug}"
  defp page_prefix(:home), do: "home"

  defp pick(list, identifier), do: Enum.at(list, rem(:erlang.phash2(identifier), length(list)))

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.CalloutTag

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context!, options) do
      context! = Registers.report(context!, tag.problems, tag.loc)
      {identifier, context!} = CalloutTag.identify(tag, context!)
      {icon, context!} = TagIcon.render(tag.icon, context!, options, tag.loc)
      {body, context!} = NestedBody.to_html(tag.body, context!, options)

      {~s(<div class="#{classes(tag)}"#{marker(identifier)}>) <>
         icon <>
         ~s(<div class="container">) <>
         checkbox(identifier) <>
         ~s(<div class="content">#{body}</div>) <>
         controls(identifier) <>
         ~s(</div></div>), context!}
    end

    defp classes(tag) do
      classes = "callout callout-#{tag.type} group/callout"
      if tag.animate?, do: classes <> " animate", else: classes
    end

    defp marker(nil), do: ""
    defp marker(identifier), do: ~s( data-callout="#{identifier}")

    defp checkbox(nil), do: ""

    defp checkbox(identifier),
      do: ~s(<input id="callout-#{identifier}" type="checkbox" class="peer hidden" />)

    defp controls(nil), do: ""

    defp controls(identifier) do
      {celebration, congratulations} = CalloutTag.congratulations(identifier)

      ~s(<label for="callout-#{identifier}" class="more tell-me-more">) <>
        ~s(Would you like to know more?</label>) <>
        ~s(<div class="controls">) <>
        ~s(<label for="callout-#{identifier}" class="less join-item">) <>
        ~s(<span class="mr-1">#{celebration}</span> #{congratulations}</label>) <>
        ~s(<button type="button" class="always-tell-me-more join-item">) <>
        ~s(<span class="mr-1">📚</span> Always tell me more!</button>) <>
        ~s(</div>) <>
        ~s(<button type="button" class="stop-telling-me-more">) <>
        ~s(<span class="mr-1">😵‍💫</span> Stop telling me more...</button>)
    end
  end
end
