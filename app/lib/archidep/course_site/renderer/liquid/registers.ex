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
  @spec report(Solid.Context.t(), RenderError.t()) :: Solid.Context.t()
  def report(%Solid.Context{} = context, %RenderError{} = error),
    do: Solid.Context.put_errors(context, error)
end
