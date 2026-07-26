defmodule ArchiDep.CourseSite.Structure.Cheatsheet do
  @moduledoc """
  One cheatsheet of the course: its slug, what it is called, and what it is
  called in a list.

  A cheatsheet's title names the thing it is a cheatsheet *of* ("Command Line
  Cheatsheet"), which is a word too many where it sits beside forty-nine other
  entries, so it may declare a shorter one. That shorter name falls back to the
  title here rather than at each place a list is drawn, so a cheatsheet is
  listed the same way wherever it is listed.

  Unlike a chapter, a cheatsheet has no number to be ordered by: the order is
  declared alongside the sections of the course.
  """

  @enforce_keys [:slug, :title]
  defstruct [:slug, :title, sidebar_title: nil]

  @type t :: %__MODULE__{
          slug: String.t(),
          title: String.t(),
          sidebar_title: String.t() | nil
        }

  @doc """
  Build a cheatsheet from its slug and what its front matter says.
  """
  @spec new(String.t(), String.t(), String.t() | nil) :: t()
  def new(slug, title, sidebar_title \\ nil)
      when is_binary(slug) and is_binary(title) and
             (is_binary(sidebar_title) or is_nil(sidebar_title)),
      do: %__MODULE__{slug: slug, title: title, sidebar_title: sidebar_title}

  @doc """
  What a cheatsheet is called in a list, which is its title when it declares
  nothing shorter.

      iex> Cheatsheet.sidebar_title(Cheatsheet.new("git", "Git Cheatsheet", "Git"))
      "Git"

      iex> Cheatsheet.sidebar_title(Cheatsheet.new("git", "Git Cheatsheet"))
      "Git Cheatsheet"
  """
  @spec sidebar_title(t()) :: String.t()
  def sidebar_title(%__MODULE__{sidebar_title: nil, title: title}), do: title
  def sidebar_title(%__MODULE__{sidebar_title: sidebar_title}), do: sidebar_title
end
