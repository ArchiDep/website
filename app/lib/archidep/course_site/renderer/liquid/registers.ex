defmodule ArchiDep.CourseSite.Renderer.Liquid.Registers do
  @moduledoc """
  How a tag reaches the document it is part of, and how it says something went
  wrong.

  `Solid` gives a tag one channel for anything that is not a variable — the
  registers of its own context — and threads it through every nested render.
  Everything the renderer puts there goes through this module, so that the key
  is named once and a tag cannot quietly start depending on the shape of someone
  else's entry.
  """

  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderError

  @register :archidep_course_site
  @identifiers :archidep_course_site_identifiers

  @doc """
  Put the rendering context where the tags of a document will look for it.
  """
  @spec put(Solid.Context.t(), RenderContext.t()) :: Solid.Context.t()
  def put(%Solid.Context{} = context, %RenderContext{} = render_context),
    do: %Solid.Context{
      context
      | registers: Map.put(context.registers, @register, render_context)
    }

  @doc """
  The rendering context of the document being rendered.

  Raises when it is absent: a tag of this renderer only ever runs on a template
  the renderer itself set up, so its absence is a broken pipeline rather than a
  problem with the content.
  """
  @spec fetch!(Solid.Context.t()) :: RenderContext.t()
  def fetch!(%Solid.Context{registers: registers}), do: Map.fetch!(registers, @register)

  @doc """
  Record that something in the document could not be rendered.

  The tag still has to return something to put on the page — usually nothing at
  all — because the point of collecting errors is to report every problem of a
  document in one go rather than the first one.
  """
  @spec report(Solid.Context.t(), RenderError.t() | [RenderError.t()]) :: Solid.Context.t()
  def report(%Solid.Context{} = context, %RenderError{} = error),
    do: Solid.Context.put_errors(context, error)

  def report(%Solid.Context{} = context, errors) when is_list(errors),
    do: Enum.reduce(errors, context, &report(&2, &1))

  @doc """
  Record what a tag could not make sense of in its own markup, at the place the
  tag is written.

  A tag knows what is wrong and where it is; which file that is comes from the
  rendering context, so no tag has to carry the path of its own document around.
  """
  @spec report(
          Solid.Context.t(),
          RenderError.reason() | [RenderError.reason()],
          Solid.Lexer.loc() | nil
        ) :: Solid.Context.t()
  def report(%Solid.Context{} = context, reasons, loc) do
    source_path = fetch!(context).source_path

    reasons
    |> List.wrap()
    |> Enum.reduce(context, &report(&2, RenderError.new(&1, source_path, loc)))
  end

  @doc """
  The identifiers the tags of this document have taken so far.

  A page names some of the things it renders — the checkbox that opens a "more"
  callout, and whatever comes after it — and two of them under one name would
  pair the wrong label with the wrong input. A tag therefore asks what is
  already taken before settling on a name, and says which one it took with
  `take_identifier/2`. It lives here rather than in the rendering context
  because the context is built once per document and never updated, while this
  grows as the document renders.
  """
  @spec identifiers(Solid.Context.t()) :: MapSet.t(String.t())
  def identifiers(%Solid.Context{registers: registers}),
    do: Map.get(registers, @identifiers, MapSet.new())

  @doc """
  Record that a tag has taken an identifier, so that no later tag of the same
  document takes it too.
  """
  @spec take_identifier(Solid.Context.t(), String.t()) :: Solid.Context.t()
  def take_identifier(%Solid.Context{registers: registers} = context, identifier)
      when is_binary(identifier),
      do: %Solid.Context{
        context
        | registers:
            Map.update(
              registers,
              @identifiers,
              MapSet.new([identifier]),
              &MapSet.put(&1, identifier)
            )
      }
end
