defmodule ArchiDep.CourseSite.HeadingRef do
  @moduledoc """
  The identity of one heading of one page: the page it is on and the identifier
  the page gives it.

  It is the vocabulary for a place *inside* a page, as
  `ArchiDep.CourseSite.PageRef` is the vocabulary for the page itself, and it
  names no URL for the same reason: the fragment a reader follows is
  `ArchiDep.CourseSite.Urls`' to write.

  A heading's identifier is settled by the renderer rather than written by an
  author, so a reference to one is only as good as the page it was read from.
  `ArchiDep.CourseSite.Headings` is what reads them, and it is where a reference
  to a heading a page does not have is refused.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef

  @enforce_keys [:page, :id]
  defstruct [:page, :id]

  @type t :: %__MODULE__{
          page: PageRef.t(),
          id: String.t()
        }

  @doc """
  Build a heading reference.

      iex> HeadingRef.new({:cheatsheet, "sysadmin"}, "how-do-i-change-my-username")
      %HeadingRef{page: {:cheatsheet, "sysadmin"}, id: "how-do-i-change-my-username"}
  """
  @spec new(PageRef.t(), String.t()) :: t()
  def new(:home, id) when is_binary(id) and id != "",
    do: %__MODULE__{page: :home, id: id}

  def new({:document, %DocumentRef{}} = page, id) when is_binary(id) and id != "",
    do: %__MODULE__{page: page, id: id}

  def new({:cheatsheet, slug} = page, id)
      when is_binary(slug) and is_binary(id) and id != "",
      do: %__MODULE__{page: page, id: id}
end
