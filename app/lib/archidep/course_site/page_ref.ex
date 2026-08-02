defmodule ArchiDep.CourseSite.PageRef do
  @moduledoc """
  A reference to a page of the course material site: the home page, a course
  document or a cheatsheet.

  A page reference carries the identity of a page, never its URL. The path
  returned by `output_path/1` is where the page lives *within* a build, without
  the deployment mount point or the year prefix that `ArchiDep.CourseSite.Urls`
  adds.

  A page URL identifies a page less precisely than a reference does: a chapter's
  subject and its exercise are emitted at one and the same URL, which is
  coherent only because a chapter never holds both. `identity/1` is that weaker
  identity, and it is what an archived edition records of each of its pages so
  that `ArchiDep.CourseSite.Archives` can match one against the current course.

  There is deliberately no way back from a path to an identity. A path is only
  ever read by the edition that emitted it, and the numbering, the slugging and
  the shape of a URL are all free to differ from one edition to the next; a
  parser here would be this edition's grammar applied to a frozen archive it
  never described. An archived path is an opaque string, compared for equality
  and nothing else.
  """

  alias ArchiDep.CourseSite.DocumentRef

  @type t :: :home | {:document, DocumentRef.t()} | {:cheatsheet, String.t()}

  @type identity ::
          :home
          | {:chapter, pos_integer(), String.t()}
          | {:chapter_slides, pos_integer(), String.t()}
          | {:cheatsheet, String.t()}

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
  Where a page of a given edition is served from, relative to the site's mount
  point: the edition's prefix followed by the page's path within its build.

  This is what names a page of an *archived* edition — the whole of the identity
  `ArchiDep.CourseSite.Urls` hands to the `/latest` resolver, and the key
  `ArchiDep.CourseSite.Archives` matches it against. It takes the path rather
  than the page so that both sides can call it: only the live edition holds a
  page reference, while an archive holds the paths it emitted and nothing more.

      iex> PageRef.edition_path("2025", PageRef.output_path({:cheatsheet, "git"}))
      "/2025/cheatsheets/git/"

      iex> PageRef.edition_path("2025", PageRef.output_path(:home))
      "/2025/"
  """
  @spec edition_path(String.t(), String.t()) :: String.t()
  def edition_path(edition, path) when is_binary(edition) and is_binary(path),
    do: "/" <> edition <> path
end
