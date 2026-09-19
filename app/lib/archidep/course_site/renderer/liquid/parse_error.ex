defmodule ArchiDep.CourseSite.Renderer.Liquid.ParseError do
  @moduledoc """
  What a tag of this renderer hands back when its markup cannot be read at all,
  there being nothing left to render.

  Every one of them is built here because of what `Solid` does with the
  location: it reads it back with `meta[:line]`, while the location it hands a
  tag to begin with is a `Solid.Parser.Loc` struct, which answers no such call.
  A tag reporting the location it was given therefore crashes the build in place
  of reporting the author's mistake. `new/2` takes the location in either shape
  and keeps the plain map, so a tag cannot report a mistake in a way that is
  itself one.
  """

  @typedoc """
  A location a tag may report a parse error at: the one `Solid` hands its
  `c:Solid.Tag.parse/3`, one of the lexer's, or the parser's own position within
  the document.
  """
  @type location :: %{
          :line => pos_integer(),
          :column => pos_integer(),
          optional(atom()) => term()
        }

  @type t :: {:error, String.t(), Solid.Lexer.loc()}

  @doc """
  A parse error at a location `Solid` can read.
  """
  @spec new(String.t(), location()) :: t()
  def new(message, %{line: line, column: column}) when is_binary(message),
    do: {:error, message, %{line: line, column: column}}
end
