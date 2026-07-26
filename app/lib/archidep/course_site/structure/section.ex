defmodule ArchiDep.CourseSite.Structure.Section do
  @moduledoc """
  One section of the course: a title and the chapters numbered for it, in
  reading order.

  A section is **declared** rather than discovered — a chapter names its section
  with the first digit of its number, and the titles are written down elsewhere
  — so its position in that list is the whole of its identity. Its number and
  its slug are functions of that position and that title rather than fields, so
  a section cannot be numbered for one place in the course and listed in
  another.
  """

  alias ArchiDep.CourseSite.Structure.Chapter

  @enforce_keys [:index, :title]
  defstruct [:index, :title, chapters: []]

  @type t :: %__MODULE__{
          index: pos_integer(),
          title: String.t(),
          chapters: [Chapter.t()]
        }

  @slug_separator ~r/\s+/
  @slug_rejected ~r/[^a-z0-9-]/

  @doc """
  Build a section from its position among the declared sections, its title and
  the chapters numbered for it.
  """
  @spec new(pos_integer(), String.t(), [Chapter.t()]) :: t()
  def new(index, title, chapters \\ [])
      when is_integer(index) and index > 0 and is_binary(title) and is_list(chapters),
      do: %__MODULE__{index: index, title: title, chapters: chapters}

  @doc """
  The number of a section, which is what a chapter's number is built on and what
  progress is recorded against.

      iex> Section.num(Section.new(5, "Advanced Deployment"))
      500
  """
  @spec num(t()) :: pos_integer()
  def num(%__MODULE__{index: index}), do: index * 100

  @doc """
  The slug of a section, which names the checkbox that folds it in the material's
  navigation.

      iex> Section.slug(Section.new(4, "Basic Deployment"))
      "basic-deployment"

      iex> Section.slug(Section.new(2, "Version Control!"))
      "version-control"
  """
  @spec slug(t()) :: String.t()
  def slug(%__MODULE__{title: title}),
    do:
      title
      |> String.downcase()
      |> String.replace(@slug_separator, "-")
      |> String.replace(@slug_rejected, "")
end
