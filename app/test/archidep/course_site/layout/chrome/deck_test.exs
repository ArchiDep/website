defmodule ArchiDep.CourseSite.Layout.Chrome.DeckTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Deck
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.SiteInfo

  @links %{
    slides_css: "/assets/course/slides.css",
    theme_slides_css: "/assets/theme/slides.css",
    slides_js: "/assets/course/slides.js",
    slides_mermaid_js: "/assets/course/slides-mermaid.js",
    heig_logo: "/favicons/heig.png",
    source: "https://github.com/ArchiDep/website/blob/abc123/course/x.md",
    page_pdf: "/pdf/Slides.pdf"
  }

  @banner_url "https://archidep.example.com/latest?to=/2025/course/507-dns/slides/"

  describe "deck/1" do
    test "hands the deck to the browser as the text of a textarea" do
      assert deck() == expected([])
    end

    test "escapes the one sequence that would end the textarea early" do
      assert deck(markdown: "Write </textarea> or </TEXTAREA> to break out.\n") ==
               expected(markdown: "Write &lt;/textarea> or &lt;/textarea> to break out.\n")
    end

    test "leaves the deck's own markup and entities exactly as they were written" do
      markdown = "<img src='x.png' />\n\n&nbsp;\n"

      assert deck(markdown: markdown) == expected(markdown: markdown)
    end

    test "offers no download for a deck nobody has printed" do
      assert deck(links: Map.delete(@links, :page_pdf)) == expected(download: "")
    end

    test "points at nothing for a checkout that cannot name its revision" do
      assert deck(links: Map.delete(@links, :source)) == expected(source: "")
    end

    test "says in the corner of an archived deck that the edition is over" do
      assert deck(banner: :archive) ==
               expected(banner: banner_markup("Archived edition", "Go to the current version."))
    end

    test "says in the corner of a deck of the backup copy where the live site is" do
      assert deck(banner: :backup) ==
               expected(banner: banner_markup("Backup copy", "Go to the live site."))
    end

    test "says only what a checkout that cannot name its branch knows" do
      assert deck(git_branch: nil, git_revision: nil, commit: nil) ==
               expected(
                 branch: ~s(\n          <li class="text-xs">v1.2.3</li>),
                 revision: "",
                 commit: ""
               )
    end
  end

  defp deck(overrides \\ []), do: render(&Deck.deck/1, %{page: page(overrides)})

  defp page(overrides) do
    %Assigns{
      ref: {:document, nil},
      kind: :deck,
      title: "Domain Name System (DNS)",
      graded?: false,
      content: %Slides{markdown: Keyword.get(overrides, :markdown, "# DNS\n")},
      toc: [],
      metadata_html: "<title>Domain Name System (DNS) · ArchiDep</title>",
      policy: %Policy{app_navigation?: true, account?: true, badges?: true, progress_cards?: true},
      banner: Keyword.get(overrides, :banner),
      site: site(overrides),
      commit: Keyword.get(overrides, :commit, "main@abc123"),
      sections: [],
      cheatsheets: [],
      cards: [],
      standalone?: false,
      legend_emoji: %{},
      search_emoji: %{},
      page_class: "course-deck",
      cloud_server: nil,
      pdf_tooltip: "Slides PDF",
      links: Keyword.get_lazy(overrides, :links, fn -> links(Keyword.get(overrides, :banner)) end)
    }
  end

  defp links(nil), do: @links
  defp links(_kind), do: Map.put(@links, :banner, @banner_url)

  defp site(overrides) do
    SiteInfo.new(
      version: "1.2.3",
      git_branch: Keyword.get(overrides, :git_branch, "main"),
      git_revision: Keyword.get(overrides, :git_revision, "abc123"),
      years: "2025-2026",
      years_short: "25-26"
    )
  end

  defp expected(parts) do
    String.trim_trailing("""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Domain Name System (DNS) · ArchiDep</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link rel="stylesheet" href="/assets/course/slides.css">
        <link rel="stylesheet" href="/assets/theme/slides.css">
        <script defer src="/assets/course/slides-mermaid.js">
        </script>
      </head>
      <body data-theme="light">
        <div class="reveal">
          <div class="slides">
            <section data-markdown>
              <textarea data-template>#{Keyword.get(parts, :markdown, "# DNS\n")}</textarea>
            </section>
          </div>
        </div>

        <script src="/assets/course/slides.js">
        </script>

        <div id="meta" class="absolute bottom-4 left-4 z-10 flex items-end gap-2 font-meta">
          <a id="heig-vd-logo" href="https://heig-vd.ch/" target="_blank" rel="noopener noreferrer">
            <img src="/favicons/heig.png" alt="HEIG-VD logo" width="40" height="40">
          </a>

          #{Keyword.get(parts, :source, source_markup(@links[:source]))}

          #{Keyword.get(parts, :download, download_markup(@links[:page_pdf]))}

          #{Keyword.get(parts, :banner, "")}
        </div>

        <div id="footer" class="tooltip absolute bottom-4 left-1/4 right-1/4 z-10 text-center font-meta text-sm opacity-25 hover:opacity-100">
          <div class="tooltip-content">
            <ul class="list-none m-0 p-0 flex flex-col gap-1">
              <li>Architecture &amp; Deployment 2025-2026</li>
              #{Keyword.get(parts, :branch, branch_markup("main"))}
              #{Keyword.get(parts, :revision, revision_markup("abc123"))}
            </ul>
          </div>
          <a href="https://archidep.ch" class="!no-underline hover:!underline">
            ArchiDep 25-26 #{Keyword.get(parts, :commit, "main@abc123")}
          </a>
        </div>
      </body>
    </html>
    """)
  end

  defp download_markup(url),
    do:
      ~s(<a id="download-pdf" href="#{url}" class="print:hidden tooltip" data-tip="Download PDF" download>\n) <>
        ~s(        #{icon(:document_arrow_down, "size-6 opacity-50 hover:opacity-100")}\n) <>
        ~s(      </a>)

  defp banner_markup(label, statement),
    do:
      ~s(<a href="#{@banner_url}" class="tooltip print:hidden" data-tip="#{statement}">\n) <>
        ~s(  <span class="badge badge-warning badge-sm">#{label}</span>\n) <>
        ~s(</a>)

  defp source_markup(url),
    do:
      ~s(<a href="#{url}" class="tooltip" data-tip="Source code" target="_blank" rel="noopener noreferrer">\n) <>
        ~s(        #{github()}\n) <>
        ~s(      </a>)

  defp branch_markup(name),
    do:
      ~s(<li class="text-xs">\n) <>
        ~s(            v1.2.3 on branch #{name}\n) <>
        ~s(          </li>\n          )

  defp revision_markup(sha),
    do:
      ~s(<li class="text-xs">\n) <>
        ~s(            Rev: #{sha}\n) <>
        ~s(          </li>)

  defp github,
    do: %{class: "size-6 opacity-50 hover:opacity-100"} |> Icons.github() |> Html.render()
end
