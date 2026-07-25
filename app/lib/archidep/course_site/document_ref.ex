defmodule ArchiDep.CourseSite.DocumentRef do
  @moduledoc """
  The identity of a course document: a chapter number, a slug and a type. Every
  chapter of the course material lives in a directory named `<num>-<slug>` and
  holds at most one document of each type.

  This is the vocabulary the renderer and `ArchiDep.Course.Material` share to
  refer to a document without naming a URL, so that URL policy (the deployment
  mount point, the year prefix) stays out of both.
  """

  @enforce_keys [:num, :slug, :type]
  defstruct [:num, :slug, :type]

  @type doc_type :: :subject | :exercise | :slides

  @type t :: %__MODULE__{
          num: pos_integer(),
          slug: String.t(),
          type: doc_type()
        }

  @source_path_regex ~r{\A_course/([1-9])(\d\d)-([^/]+)/(subject|exercise|slides|slides/slides)\.md\z}

  @doc """
  Build a document reference.
  """
  @spec new(pos_integer(), String.t(), doc_type()) :: t()
  def new(num, slug, type)
      when is_integer(num) and num > 0 and is_binary(slug) and
             type in [:subject, :exercise, :slides],
      do: %__MODULE__{num: num, slug: slug, type: type}

  @doc """
  The chapter directory of a document, shared by every document of a chapter.

      iex> DocumentRef.dir(DocumentRef.new(401, "cloud-computing", :slides))
      "401-cloud-computing"
  """
  @spec dir(t()) :: String.t()
  def dir(%__MODULE__{num: num, slug: slug}), do: "#{num}-#{slug}"

  @doc """
  Parse the source path of a course document, as written in a `{% link %}` tag.

  Slides come in two source layouts — `slides.md` at the chapter root and
  `slides/slides.md` in a subdirectory — which are the same document as far as
  its identity and its URL are concerned.

      iex> DocumentRef.parse_source_path("_course/402-run-virtual-server/exercise.md")
      {:ok, DocumentRef.new(402, "run-virtual-server", :exercise)}

      iex> DocumentRef.parse_source_path("_course/101-command-line/slides/slides.md")
      {:ok, DocumentRef.new(101, "command-line", :slides)}

      iex> DocumentRef.parse_source_path("_course/101-command-line/notes.md")
      {:error, {:invalid_source_path, "_course/101-command-line/notes.md"}}
  """
  @spec parse_source_path(String.t()) ::
          {:ok, t()} | {:error, {:invalid_source_path, String.t()}}
  def parse_source_path(source_path) when is_binary(source_path) do
    case Regex.run(@source_path_regex, source_path) do
      [_match, section, chapter, slug, file] ->
        num = String.to_integer(section) * 100 + String.to_integer(chapter)
        {:ok, new(num, slug, source_path_type(file))}

      nil ->
        {:error, {:invalid_source_path, source_path}}
    end
  end

  defp source_path_type("subject"), do: :subject
  defp source_path_type("exercise"), do: :exercise
  defp source_path_type("slides"), do: :slides
  defp source_path_type("slides/slides"), do: :slides
end
