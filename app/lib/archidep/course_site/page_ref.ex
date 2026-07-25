defmodule ArchiDep.CourseSite.PageRef do
  @moduledoc """
  A reference to a page of the course material site: the home page, a course
  document or a cheatsheet.

  A page reference carries the identity of a page, never its URL. The path
  returned by `output_path/1` is where the page lives *within* a build, without
  the deployment mount point or the year prefix that `ArchiDep.CourseSite.Urls`
  adds.

  A page URL identifies a page less precisely than a reference does: a chapter's
  subject and its exercise share one URL. `identity/1` is that weaker identity,
  and it is what `parse_output_path/1` recovers from a path — enough to match an
  archived page against the current edition of the course, which is the reason
  the inverse direction exists.
  """

  alias ArchiDep.CourseSite.DocumentRef

  @type t :: :home | {:document, DocumentRef.t()} | {:cheatsheet, String.t()}

  @type identity ::
          :home
          | {:chapter, pos_integer(), String.t()}
          | {:chapter_slides, pos_integer(), String.t()}
          | {:cheatsheet, String.t()}

  @document_path_regex ~r{\A/course/([1-9]\d\d)-([^/]+)/(slides/)?\z}
  @cheatsheet_path_regex ~r{\A/cheatsheets/([^/]+)/\z}

  @doc """
  The path of a page within a build, always starting and ending with a slash.

  Both slides source layouts produce the same URL, one segment below the
  chapter's other documents.

      iex> PageRef.output_path(:home)
      "/"

      iex> PageRef.output_path({:document, DocumentRef.new(402, "run-virtual-server", :exercise)})
      "/course/402-run-virtual-server/"

      iex> PageRef.output_path({:document, DocumentRef.new(401, "cloud-computing", :slides)})
      "/course/401-cloud-computing/slides/"

      iex> PageRef.output_path({:cheatsheet, "sysadmin"})
      "/cheatsheets/sysadmin/"
  """
  @spec output_path(t()) :: String.t()
  def output_path(:home), do: "/"

  def output_path({:document, %DocumentRef{type: :slides} = document}),
    do: "/course/#{DocumentRef.dir(document)}/slides/"

  def output_path({:document, %DocumentRef{} = document}),
    do: "/course/#{DocumentRef.dir(document)}/"

  def output_path({:cheatsheet, slug}) when is_binary(slug), do: "/cheatsheets/#{slug}/"

  @doc """
  The identity a page's URL preserves. A chapter holds either a subject or an
  exercise, never both, so both map to the same chapter identity.

      iex> PageRef.identity({:document, DocumentRef.new(402, "run-virtual-server", :exercise)})
      {:chapter, 402, "run-virtual-server"}

      iex> PageRef.identity({:document, DocumentRef.new(402, "run-virtual-server", :subject)})
      {:chapter, 402, "run-virtual-server"}

      iex> PageRef.identity({:document, DocumentRef.new(401, "cloud-computing", :slides)})
      {:chapter_slides, 401, "cloud-computing"}
  """
  @spec identity(t()) :: identity()
  def identity(:home), do: :home

  def identity({:document, %DocumentRef{num: num, slug: slug, type: :slides}}),
    do: {:chapter_slides, num, slug}

  def identity({:document, %DocumentRef{num: num, slug: slug}}), do: {:chapter, num, slug}

  def identity({:cheatsheet, slug}) when is_binary(slug), do: {:cheatsheet, slug}

  @doc """
  Parse the path of a page within a build back into the identity that path
  preserves.

      iex> PageRef.parse_output_path("/course/401-cloud-computing/slides/")
      {:ok, {:chapter_slides, 401, "cloud-computing"}}

      iex> PageRef.parse_output_path("/course/402-run-virtual-server/")
      {:ok, {:chapter, 402, "run-virtual-server"}}

      iex> PageRef.parse_output_path("/cheatsheets/git/")
      {:ok, {:cheatsheet, "git"}}

      iex> PageRef.parse_output_path("/course/101-command-line/images/cli.jpg")
      {:error, {:invalid_output_path, "/course/101-command-line/images/cli.jpg"}}
  """
  @spec parse_output_path(String.t()) ::
          {:ok, identity()} | {:error, {:invalid_output_path, String.t()}}
  def parse_output_path("/"), do: {:ok, :home}

  def parse_output_path(path) when is_binary(path) do
    with nil <- parse_document_path(path),
         nil <- parse_cheatsheet_path(path) do
      {:error, {:invalid_output_path, path}}
    end
  end

  defp parse_document_path(path) do
    case Regex.run(@document_path_regex, path) do
      [_match, num, slug] -> {:ok, {:chapter, String.to_integer(num), slug}}
      [_match, num, slug, "slides/"] -> {:ok, {:chapter_slides, String.to_integer(num), slug}}
      nil -> nil
    end
  end

  defp parse_cheatsheet_path(path) do
    case Regex.run(@cheatsheet_path_regex, path) do
      [_match, slug] -> {:ok, {:cheatsheet, slug}}
      nil -> nil
    end
  end
end
