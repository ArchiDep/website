defmodule Mix.Tasks.Archidep.CourseSite.Structure do
  @shortdoc "Work out what the course is from the real content and print it"

  @moduledoc """
  Read the real content directory and the real declarations, work out the
  structure of the course, and print it.

  This is the check the structure exists for: a chapter in a section nobody
  declared, a document with no title or a cheatsheet nobody listed is reported
  here rather than published as a blank entry. **It writes nothing.**

      mix archidep.course_site.structure

  Options:

  - `--content` — the course collections directory. Defaults to
    `../course/collections`.
  - `--declarations` — the file declaring the sections of the course and the
    order of its cheatsheets. Defaults to `../course/_data/course.yml`.
  """

  use Mix.Task

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section

  @requirements ["app.config"]

  @app_dir Path.expand("../../../../..", __DIR__)

  @impl Mix.Task
  def run(args) do
    {opts, [], []} =
      OptionParser.parse(args, strict: [content: :string, declarations: :string])

    content_dir = Keyword.get(opts, :content, Path.join(@app_dir, "../course/collections"))

    declarations_file =
      Keyword.get(opts, :declarations, Path.join(@app_dir, "../course/_data/course.yml"))

    tree = tree!(content_dir)
    front_matter = tree |> sources!(content_dir) |> Build.front_matter()
    declarations = declarations!(declarations_file)

    tree
    |> Structure.plan(front_matter, declarations)
    |> report()
  end

  defp tree!(content_dir) do
    case Build.content_tree(content_dir) do
      {:ok, tree} ->
        tree

      {:error, errors} ->
        abort!("The content directory could not be read", errors)
    end
  end

  defp sources!(tree, content_dir) do
    case Build.sources(tree, content_dir) do
      {:ok, sources} ->
        Mix.shell().info("Read #{map_size(sources)} pages from #{content_dir}")
        sources

      {:error, errors} ->
        abort!("The pages of the content directory could not be read", errors)
    end
  end

  defp declarations!(file) do
    case Build.declarations(file) do
      {:ok, declarations} ->
        declarations

      {:error, errors} ->
        abort!("The course declarations could not be read", errors)
    end
  end

  defp report({:ok, %Structure{sections: sections, cheatsheets: cheatsheets} = structure}) do
    Enum.each(sections, &describe_section/1)
    Mix.shell().info("Cheatsheets")
    Enum.each(cheatsheets, &describe_cheatsheet/1)

    chapters = Structure.chapters(structure)
    with_slides = Enum.count(chapters, &Chapter.slides?/1)
    are_slides = Enum.count(chapters, &(&1.page.type == :slides))

    Mix.shell().info(
      "#{length(sections)} sections, #{length(chapters)} chapters (#{with_slides} with slides beside their page, #{are_slides} that are slides) and #{length(cheatsheets)} cheatsheets"
    )
  end

  defp report({:error, errors}) do
    Mix.shell().error("#{length(errors)} problems with what the course says it is:")
    Enum.each(errors, &Mix.shell().error("  " <> Structure.format_error(&1)))
    exit({:shutdown, 1})
  end

  defp describe_section(%Section{} = section) do
    Mix.shell().info(
      "#{Section.num(section)} #{section.title} (#{Section.slug(section)}, #{length(section.chapters)} chapters)"
    )

    Enum.each(section.chapters, &describe_chapter/1)
  end

  defp describe_chapter(%Chapter{} = chapter) do
    kinds =
      [
        to_string(chapter.page.type),
        if(chapter.graded?, do: "graded"),
        if(Chapter.slides?(chapter), do: "slides")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    Mix.shell().info(
      "  #{Chapter.num(chapter)} #{chapter.title} (#{Chapter.slug(chapter)}, #{kinds})"
    )
  end

  defp describe_cheatsheet(%Cheatsheet{} = cheatsheet) do
    Mix.shell().info(
      "  #{cheatsheet.title} (#{cheatsheet.slug}, listed as #{Cheatsheet.sidebar_title(cheatsheet)})"
    )
  end

  defp abort!(what, errors) do
    Mix.shell().error("#{what}:")
    Enum.each(errors, &Mix.shell().error("  " <> Build.format_error(&1)))
    exit({:shutdown, 1})
  end
end
