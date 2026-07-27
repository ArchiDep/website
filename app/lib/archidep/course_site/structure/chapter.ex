defmodule ArchiDep.CourseSite.Structure.Chapter do
  @moduledoc """
  One chapter of the course: the page the material lists it as, and the deck
  beside that page when it has one.

  **A chapter is the unit, not a document.** A chapter's page is its subject,
  its exercise, or a deck standing on its own, and `slides` is a *second*
  document of the same chapter. So a chapter with a deck is one entry that has
  slides, never two entries — there is no rule here that hides a document from a
  listing, because there is no document to hide. That is only coherent under the
  rules `ArchiDep.CourseSite.Build.ContentTree` enforces: a chapter has a
  subject or an exercise, never both, and an exercise never has slides.

  What a chapter is called and whether it is graded are read from the front
  matter of its page. Everything else is a function of its number, which
  `ArchiDep.CourseSite.DocumentRef` already carries, so a chapter cannot claim
  to be in one section and numbered for another.
  """

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef

  @enforce_keys [:page, :title]
  defstruct [:page, :title, slides: nil, graded?: false]

  @type t :: %__MODULE__{
          page: DocumentRef.t(),
          title: String.t(),
          slides: DocumentRef.t() | nil,
          graded?: boolean()
        }

  @doc """
  Build a chapter from the document its page is and what its front matter says.

  Options:

  - `:slides` — the chapter's deck, when its page is not the deck itself.
  - `:graded?` — whether the chapter is a graded exercise. Defaults to `false`.
  """
  @spec new(DocumentRef.t(), String.t(), keyword()) :: t()
  def new(%DocumentRef{} = page, title, opts \\ []) when is_binary(title) and is_list(opts),
    do: %__MODULE__{
      page: page,
      title: title,
      slides: Keyword.get(opts, :slides),
      graded?: Keyword.get(opts, :graded?, false)
    }

  @doc """
  The page a chapter is listed as, as a reference anything that emits a URL or
  links into the page can take.

      iex> Chapter.page_ref(Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System"))
      {:document, DocumentRef.new(507, "dns", :subject)}
  """
  @spec page_ref(t()) :: PageRef.t()
  def page_ref(%__MODULE__{page: page}), do: {:document, page}

  @doc """
  The number of a chapter, which every document of it shares.

      iex> Chapter.num(Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System"))
      507
  """
  @spec num(t()) :: pos_integer()
  def num(%__MODULE__{page: %DocumentRef{num: num}}), do: num

  @doc """
  The slug of a chapter, which names its directory and its URL.

      iex> Chapter.slug(Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System"))
      "dns"
  """
  @spec slug(t()) :: String.t()
  def slug(%__MODULE__{page: %DocumentRef{slug: slug}}), do: slug

  @doc """
  The section a chapter belongs to, which is the first digit of its number.

      iex> Chapter.section(Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System"))
      5
  """
  @spec section(t()) :: pos_integer()
  def section(%__MODULE__{} = chapter), do: div(num(chapter), 100)

  @doc """
  The position of a chapter within its section, which is the last two digits of
  its number.

      iex> Chapter.section_chapter(Chapter.new(DocumentRef.new(507, "dns", :subject), "Domain Name System"))
      7
  """
  @spec section_chapter(t()) :: non_neg_integer()
  def section_chapter(%__MODULE__{} = chapter), do: rem(num(chapter), 100)

  @doc """
  Whether a chapter has a deck beside its page.

      iex> subject = DocumentRef.new(401, "cloud-computing", :subject)
      iex> Chapter.slides?(Chapter.new(subject, "Cloud Computing", slides: DocumentRef.new(401, "cloud-computing", :slides)))
      true

  A chapter whose page *is* a deck has none: it is one page showing slides, not a
  page with slides beside it.

      iex> Chapter.slides?(Chapter.new(DocumentRef.new(403, "linux", :slides), "Linux"))
      false
  """
  @spec slides?(t()) :: boolean()
  def slides?(%__MODULE__{slides: slides}), do: slides != nil
end
