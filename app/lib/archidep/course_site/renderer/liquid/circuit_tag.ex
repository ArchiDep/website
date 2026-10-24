defmodule ArchiDep.CourseSite.Renderer.Liquid.CircuitTag do
  @moduledoc """
  `{% circuit name: register-bit, clock: running %}` — a logic circuit the
  reader can operate, drawn in the browser by the `<logic-diagram>` element of
  the `companion-gate` package, with the instructions that say what to do with
  it.

  The body is those instructions, and it may be empty. They are part of the
  circuit's figure rather than prose before it, so that the page can show them
  with the circuit wherever the circuit is shown.

  The element's attributes are written as the tag's, and every circuit of a page
  shows its names and no controls unless it says otherwise. `width` is the
  widest the circuit is drawn in the page, in pixels. An attribute the element
  does not have is reported and left out, as is a `width` that is not a number
  of pixels. A value the element cannot use is the element's to report, since it
  is the one that knows its circuits and their inputs.
  """

  @behaviour Solid.Tag

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes
  alias ArchiDep.CourseSite.Renderer.Liquid.NestedBody
  alias ArchiDep.CourseSite.Renderer.RenderError

  @defaults %{"controls" => "none", "names" => "true"}

  # The element's own attributes, in the order they are written out. `fixed` is
  # one it reads by its presence alone.
  @element_attributes ~w(name autoplay clock controls fixed focus highlight inputs names speed theme)

  @enforce_keys [:loc, :attributes, :width, :body, :problems]
  defstruct [:loc, :attributes, :width, :body, :problems]

  @type t :: %__MODULE__{
          loc: Solid.Lexer.loc(),
          attributes: [{String.t(), String.t() | true}],
          width: pos_integer() | nil,
          body: Solid.Parser.parse_tree(),
          problems: [RenderError.reason()]
        }

  @impl Solid.Tag
  def parse("circuit", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, attributes} <- Attributes.parse(tokens),
         {:ok, body, context} <- NestedBody.parse(context, "endcircuit") do
      {width, width_problems} = width(attributes)
      {element_attributes, attribute_problems} = element_attributes(attributes)

      {:ok,
       %__MODULE__{
         loc: loc,
         attributes: element_attributes,
         width: width,
         body: body,
         problems: name_problems(attributes) ++ attribute_problems ++ width_problems
       }, context}
    end
  end

  defp name_problems(attributes) do
    case Map.get(attributes, "name") do
      name when is_binary(name) and name != "" -> []
      _missing -> [{:invalid_tag, "circuit", "A circuit must have a name"}]
    end
  end

  defp element_attributes(attributes) do
    {given, unknown} =
      @defaults
      |> Map.merge(Map.delete(attributes, "width"))
      |> Map.split(@element_attributes)

    {fixed, fixed_problems} = fixed(Map.get(given, "fixed"))
    known = given |> Map.delete("fixed") |> Map.merge(fixed)

    written =
      for name <- @element_attributes, Map.has_key?(known, name) do
        {name, value(Map.fetch!(known, name))}
      end

    unknown_problems =
      unknown
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(&{:invalid_tag, "circuit", "Unknown attribute #{inspect(&1)}"})

    {written, fixed_problems ++ unknown_problems}
  end

  defp fixed(nil), do: {%{}, []}
  defp fixed("true"), do: {%{"fixed" => true}, []}
  defp fixed("false"), do: {%{}, []}

  defp fixed(value),
    do:
      {%{},
       [
         {:invalid_tag, "circuit",
          "fixed must be true or false, not #{inspect(to_string(value))}"}
       ]}

  defp value(true), do: true
  defp value(value), do: to_string(value)

  defp width(attributes) do
    case Map.get(attributes, "width") do
      nil ->
        {nil, []}

      width when is_integer(width) and width > 0 ->
        {width, []}

      width ->
        {nil,
         [
           {:invalid_tag, "circuit",
            "width must be a number of pixels, not #{inspect(to_string(width))}"}
         ]}
    end
  end

  defimpl Solid.Renderable do
    alias ArchiDep.CourseSite.Renderer.Liquid.Registers

    @spec render(term(), Solid.Context.t(), keyword()) :: {iodata(), Solid.Context.t()}
    def render(tag, context!, options) do
      context! = Registers.report(context!, tag.problems, tag.loc)
      {body, context!} = NestedBody.to_html(tag.body, context!, options)

      {~s(<figure class="circuit">) <>
         instructions(String.trim(body)) <>
         ~s(<logic-diagram#{attributes(tag)}></logic-diagram>) <>
         ~s(</figure>), context!}
    end

    defp instructions(""), do: ""
    defp instructions(body), do: ~s(<div class="circuit-instructions">#{body}</div>)

    defp attributes(tag) do
      Enum.map_join(tag.attributes, &attribute/1) <> style(tag.width)
    end

    defp attribute({name, true}), do: " #{name}"
    defp attribute({name, value}), do: ~s( #{name}="#{escape(value)}")

    defp style(nil), do: ""
    defp style(width), do: ~s( style="max-width: #{width}px")

    defp escape(value) do
      value
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\"", "&quot;")
    end
  end
end
