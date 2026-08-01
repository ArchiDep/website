defmodule ArchiDep.CourseSite.Layout.Chrome.ArticleTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Article
  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Home
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias ArchiDep.CourseSite.Layout.Chrome.Legend
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Layout.Chrome.Presentation
  alias ArchiDep.CourseSite.Layout.Chrome.Toc
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.SiteInfo

  @entry %Entry{id: "what", level: 2, label_html: "What", entries: []}
  @source "https://github.com/ArchiDep/website/blob/abc123/course/collections/x.md"

  describe "article/1" do
    test "shows a cheatsheet bare, with nothing said before it says anything" do
      assert article() == expected([])
    end

    test "opens a presented chapter with the deck it was presented with" do
      deck = "/course/507-dns/slides/"

      assert article(
               kind: :subject,
               page_class: "course-subject",
               pdf_tooltip: "Subject PDF",
               links: Map.put(links(), :deck, deck)
             ) ==
               expected(
                 page_class: "course-subject",
                 opening: render(&Presentation.presentation/1, %{url: deck})
               )
    end

    test "opens an exercise with the key to its pictures" do
      assert article(kind: :exercise, graded?: true, page_class: "course-exercise") ==
               expected(
                 page_class: "course-exercise",
                 opening: render(&Legend.legend/1, %{graded?: true, emoji: legend_emoji()})
               )
    end

    test "names the home page by the course rather than by a line of front matter" do
      assert article(kind: :home, page_class: "course-home") ==
               expected(
                 page_class: "course-home",
                 title: render(&Home.title/1, %{links: links(), badges?: true}),
                 opening: render(&Home.welcome/1, %{})
               )
    end

    test "offers a page as a PDF once one has been published for it" do
      assert article(links: Map.put(links(), :page_pdf, "/pdf/Git.pdf")) ==
               expected(
                 page_pdf: download_markup("/pdf/Git.pdf", "Cheatsheet PDF", :document_arrow_down)
               )
    end

    test "offers a chapter's deck as a PDF beside the chapter's own" do
      links =
        links() |> Map.put(:page_pdf, "/pdf/DNS.pdf") |> Map.put(:deck_pdf, "/pdf/Slides.pdf")

      assert article(links: links) ==
               expected(
                 page_pdf:
                   download_markup("/pdf/DNS.pdf", "Cheatsheet PDF", :document_arrow_down),
                 deck_pdf:
                   download_markup("/pdf/Slides.pdf", "Slides PDF", :presentation_chart_line)
               )
    end

    test "offers no source for a checkout that cannot name its revision" do
      assert article(links: Map.delete(links(), :source)) == expected(source: "")
    end

    test "makes room for the reader's own server where a page talks about one" do
      assert article(cloud_server: "student") ==
               expected(
                 cloud_server: cloud_server_markup("student"),
                 aside_cloud_server: aside_cloud_server_markup("student")
               )
    end

    test "shows no navigation at all for a page with no headings" do
      assert article(toc: []) == expected(inline_toc: "", toc: toc_markup([]))
    end
  end

  defp article(overrides \\ []), do: render(&Article.article/1, %{page: page(overrides)})

  defp page(overrides) do
    %Assigns{
      ref: {:cheatsheet, "git"},
      kind: Keyword.get(overrides, :kind, :cheatsheet),
      title: "Git Cheatsheet",
      graded?: Keyword.get(overrides, :graded?, false),
      content: %Page{
        html: "<p>Body.</p>",
        excerpt_html: "<p>Open.</p>",
        toc: [@entry]
      },
      toc: Keyword.get(overrides, :toc, [@entry]),
      metadata_html: "",
      policy: %Policy{app_navigation?: true, account?: true, badges?: true},
      site:
        SiteInfo.new(
          version: "1.2.3",
          git_branch: "main",
          git_revision: "abc123",
          years: "2025-2026",
          years_short: "25-26"
        ),
      commit: "main@abc123",
      sections: [],
      cheatsheets: [],
      base_path: "",
      standalone?: false,
      legend_emoji: legend_emoji(),
      page_class: Keyword.get(overrides, :page_class, "course-cheatsheet"),
      cloud_server: Keyword.get(overrides, :cloud_server, nil),
      pdf_tooltip: Keyword.get(overrides, :pdf_tooltip, "Cheatsheet PDF"),
      links: Keyword.get(overrides, :links, links())
    }
  end

  defp links, do: %{source: @source, logo: "/logo.png", heig_logo: "/heig.png"}

  defp legend_emoji,
    do:
      Map.new(
        ~w(trophy scroll exclamation question space_invader checkered_flag classical_building boom),
        &{&1, "<E:#{&1}>"}
      )

  defp expected(parts) do
    String.trim_trailing("""
    <div class="flex flex-wrap xl:flex-nowrap justify-center gap-4 mx-auto">
      <div class="p-4 lg:p-6 xl:p-8 rounded md:rounded-lg lg:rounded-xl xl:rounded-2xl w-full bg-linear-to-br from-transparent to-zinc-200 dark:from-transparent dark:to-zinc-800/40 md:w-auto">
        <main class="prose prose-lg xl:prose-xl 2xl:prose-2xl sm:max-md:max-w-none #{Keyword.get(parts, :page_class, "course-cheatsheet")}">
          #{Keyword.get(parts, :title, title_markup("Git Cheatsheet"))}

          <div class="my-4"><p>Open.</p></div>

          #{Keyword.get(parts, :inline_toc, inline_toc_markup())}

          #{Keyword.get(parts, :cloud_server, "")}

          #{Keyword.get(parts, :opening, "")}

          <p>Body.</p>

          <div class="xl:hidden w-full flex justify-center items-center">
            <a href="#top" id="back-to-top-bottom" class="btn btn-ghost btn-sm">
              #{icon(:arrow_up, "size-4")} Back to top
            </a>
          </div>
        </main>
      </div>
      <aside class="hidden xl:block xl:w-xs">
        <h2 id="on-this-page-title" class="text-xl font-bold">On this page</h2>
        <nav class="toc" aria-labelledby="on-this-page-title">
          #{Keyword.get(parts, :toc, toc_markup([@entry]))}
        </nav>
        <div class="my-4 pl-4 flex items-center gap-4">
          #{Keyword.get(parts, :page_pdf, "")}
          #{Keyword.get(parts, :deck_pdf, "")}
          #{Keyword.get(parts, :source, source_markup(@source))}
        </div>
        <div class="pt-2 sticky top-0">
          #{Keyword.get(parts, :aside_cloud_server, "")}

          <a href="#top" id="back-to-top-side" class="btn btn-ghost btn-sm">
            #{icon(:arrow_up, "size-4")} Back to top
          </a>
        </div>
      </aside>
    </div>
    """)
  end

  defp title_markup(title),
    do:
      ~s(<h1 class="text-2xl md:text-3xl lg:text-4xl xl:text-5xl 2xl:text-5xl !mb-0">\n) <>
        ~s(  #{title}\n) <>
        ~s(</h1>)

  defp inline_toc_markup,
    do:
      ~s(<div class="my-4 toc collapse screen:collapse-arrow print:collapse-open bg-neutral/25 dark:bg-neutral border-base-300 border xl:hidden">\n) <>
        ~s(        <input type="checkbox">\n) <>
        ~s(        <div id="on-this-page-inline-title" class="collapse-title text-xl font-bold">\n) <>
        ~s(          <span class="print:hidden">On this page</span>\n) <>
        ~s(          <span class="hidden print:inline">Table of contents</span>\n) <>
        ~s(        </div>\n) <>
        ~s(        <nav class="toc collapse-content text-sm" aria-labelledby="on-this-page-inline-title">\n) <>
        ~s(          #{toc_markup([@entry])}\n) <>
        ~s(        </nav>\n) <>
        ~s(      </div>)

  defp toc_markup(entries), do: render(&Toc.toc/1, %{entries: entries})

  defp cloud_server_markup(mode),
    do:
      ~s(<div class="pt-2 sticky top-0 z-10">\n) <>
        ~s(        <div class="cloud-server-data not-prose xl:hidden" data-mode="#{mode}" data-layout="horizontal">\n) <>
        ~s(        </div>\n) <>
        ~s(      </div>)

  defp aside_cloud_server_markup(mode),
    do: ~s(<div class="cloud-server-data" data-mode="#{mode}">\n      </div>)

  defp download_markup(url, tooltip, name),
    do:
      ~s(<a href="#{url}" class="tooltip" data-tip="#{tooltip}" download>\n) <>
        ~s(        #{icon(name, "size-6 opacity-50 hover:opacity-100")}\n) <>
        ~s(      </a>)

  defp source_markup(url),
    do:
      ~s(<a href="#{url}" class="tooltip" data-tip="Source code" target="_blank" rel="noopener noreferrer">\n) <>
        ~s(        #{github()}\n) <>
        ~s(      </a>)

  defp github,
    do: %{class: "size-6 opacity-50 hover:opacity-100"} |> Icons.github() |> Html.render()
end
