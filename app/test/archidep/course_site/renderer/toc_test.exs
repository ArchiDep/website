defmodule ArchiDep.CourseSite.Renderer.TocTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.Toc
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.Support.CourseSiteFactory

  describe "extract/1" do
    test "nests the headings a heading introduces under it" do
      assert toc("""
             ## Deploying

             ### Over SFTP

             ### Over SSH

             ## Troubleshooting
             """) ==
               [
                 %Entry{
                   id: "deploying",
                   level: 2,
                   label_html: "Deploying",
                   entries: [
                     %Entry{id: "over-sftp", level: 3, label_html: "Over SFTP"},
                     %Entry{id: "over-ssh", level: 3, label_html: "Over SSH"}
                   ]
                 },
                 %Entry{id: "troubleshooting", level: 2, label_html: "Troubleshooting"}
               ]
    end

    test "nests the headings of a page that skips a level" do
      assert toc("# Reverse proxying\n\n#### An aside\n\n# Certificates\n") ==
               [
                 %Entry{
                   id: "reverse-proxying",
                   level: 1,
                   label_html: "Reverse proxying",
                   entries: [%Entry{id: "an-aside", level: 4, label_html: "An aside"}]
                 },
                 %Entry{id: "certificates", level: 1, label_html: "Certificates"}
               ]
    end

    test "leaves a heading shallower than the one before it where the page put it" do
      assert toc("### A first thought\n\n## Permissions\n") ==
               [
                 %Entry{id: "a-first-thought", level: 3, label_html: "A first thought"},
                 %Entry{id: "permissions", level: 2, label_html: "Permissions"}
               ]
    end

    test "labels an entry with the heading's own markup" do
      assert toc("## :boom: `mysqldump` fails and it's *bad*\n") ==
               [
                 %Entry{
                   id: "mysqldump-fails-and-its-bad",
                   level: 2,
                   label_html: ":boom: <code>mysqldump</code> fails and it’s <em>bad</em>"
                 }
               ]
    end

    test "tells apart the entries of a heading a page writes twice" do
      assert toc("## Troubleshooting\n\nProse.\n\n## Troubleshooting\n") ==
               [
                 %Entry{id: "troubleshooting", level: 2, label_html: "Troubleshooting"},
                 %Entry{id: "troubleshooting-1", level: 2, label_html: "Troubleshooting"}
               ]
    end

    test "gives a page that writes no heading nothing to navigate" do
      assert toc("A page of prose, with a `## heading` in code.\n") == []
    end

    test "leaves the headings a page shows as code out of it" do
      assert toc("```html\n<h2 id=\"nginx\">Welcome to nginx!</h2>\n```\n") == []
    end
  end

  defp toc(markdown) do
    {html, []} = Markdown.to_html(markdown, CourseSiteFactory.build(:render_context))

    Toc.extract(html)
  end
end
