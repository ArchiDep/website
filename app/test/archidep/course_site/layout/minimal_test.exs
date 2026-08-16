defmodule ArchiDep.CourseSite.Layout.MinimalTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Layout.Minimal
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure

  @metadata %PageMetadata{
    title: "Domain Name System (DNS) · ArchiDep",
    page_title: "Domain Name System (DNS)",
    description: "Learn the basics of DNS.",
    canonical_url: nil,
    robots: nil
  }

  describe "document/1" do
    test "wraps a page in its opening, its navigation and the rest of it" do
      page = %Page{
        excerpt_html: "<p>Learn the basics of DNS.</p>",
        toc: [
          %Entry{
            id: "dns-zone",
            level: 2,
            label_html: "DNS zone",
            entries: [%Entry{id: "records", level: 3, label_html: "Records", entries: []}]
          }
        ],
        html: "<h2 id=\"dns-zone\">DNS zone</h2>"
      }

      assert Minimal.document(context(page)) ==
               {:ok,
                expected_page(
                  opening: "<header>\n<p>Learn the basics of DNS.</p>\n</header>\n",
                  navigation:
                    "<nav>\n<ul><li><a href=\"#dns-zone\">DNS zone</a>" <>
                      "<ul><li><a href=\"#records\">Records</a></li></ul></li></ul>\n</nav>\n",
                  body: "<h2 id=\"dns-zone\">DNS zone</h2>"
                )}
    end

    test "leaves out the opening and the navigation of a page that has neither" do
      page = %Page{excerpt_html: nil, toc: [], html: "<p>A cheatsheet.</p>"}

      assert Minimal.document(context(page)) ==
               {:ok, expected_page(opening: "", navigation: "", body: "<p>A cheatsheet.</p>")}
    end

    test "hands a deck to the browser as the text of a textarea" do
      deck = %Slides{markdown: "# Title\n\n<img src='x.png' />\n\n&nbsp;\n"}

      assert Minimal.document(context(deck)) ==
               {:ok, expected_deck("# Title\n\n<img src='x.png' />\n\n&nbsp;\n")}
    end

    test "escapes the one sequence that would end the textarea early" do
      deck = %Slides{markdown: "Write </textarea> or </TEXTAREA> to break out.\n"}

      assert Minimal.document(context(deck)) ==
               {:ok, expected_deck("Write &lt;/textarea> or &lt;/textarea> to break out.\n")}
    end
  end

  defp context(content) do
    LayoutContext.new(
      page: {:document, DocumentRef.new(507, "dns", :subject)},
      source_path: "chapters/507-dns/subject.md",
      content: content,
      metadata: @metadata,
      front_matter: %{"title" => "Domain Name System (DNS)"},
      structure: %Structure{sections: [], cheatsheets: []},
      progress: Progress.new([]),
      statuses: %{},
      urls: build(:url_context, version: nil),
      site:
        SiteInfo.new(
          version: "0.1.0",
          git_branch: "main",
          git_revision: "abc123",
          years: "2025-2026",
          years_short: "25-26"
        )
    )
  end

  defp expected_page(parts) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    #{PageMetadata.to_html(@metadata)}
    </head>
    <body>
    #{parts[:opening]}#{parts[:navigation]}<main>
    #{parts[:body]}
    </main>
    </body>
    </html>
    """
  end

  defp expected_deck(markdown) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    #{PageMetadata.to_html(@metadata)}
    </head>
    <body>
    <div class="reveal"><div class="slides"><section data-markdown><textarea data-template>
    #{markdown}
    </textarea></section></div></div>
    </body>
    </html>
    """
  end
end
