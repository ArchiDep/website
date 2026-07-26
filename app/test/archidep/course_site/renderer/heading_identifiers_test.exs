defmodule ArchiDep.CourseSite.Renderer.HeadingIdentifiersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.HeadingIdentifiers
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.Support.CourseSiteFactory

  describe "run/1" do
    test "moves the shortcode a heading opens with, and the space after it, out of its text" do
      {:ok, %MDEx.Document{nodes: [heading]} = document} =
        Markdown.parse("## :exclamation: Create your server\n", context())

      assert HeadingIdentifiers.run(document) ==
               %{
                 document
                 | nodes: [
                     %{
                       heading
                       | nodes: [
                           %MDEx.HtmlInline{literal: ":exclamation: "},
                           %MDEx.Text{literal: "Create your server"}
                         ]
                     }
                   ]
               }
    end

    test "moves a shortcode standing in the middle of a heading out of its text" do
      {:ok, %MDEx.Document{nodes: [heading]} = document} =
        Markdown.parse("# The :books: reading list\n", context())

      assert HeadingIdentifiers.run(document) ==
               %{
                 document
                 | nodes: [
                     %{
                       heading
                       | nodes: [
                           %MDEx.Text{literal: "The "},
                           %MDEx.HtmlInline{literal: ":books: "},
                           %MDEx.Text{literal: "reading list"}
                         ]
                     }
                   ]
               }
    end

    test "moves a shortcode ending a heading out of its text" do
      {:ok, %MDEx.Document{nodes: [heading]} = document} =
        Markdown.parse("### That is all :tada:\n", context())

      assert HeadingIdentifiers.run(document) ==
               %{
                 document
                 | nodes: [
                     %{
                       heading
                       | nodes: [
                           %MDEx.Text{literal: "That is all "},
                           %MDEx.HtmlInline{literal: ":tada:"}
                         ]
                     }
                   ]
               }
    end

    test "moves the shortcode a heading opens with out of its text before code" do
      {:ok, %MDEx.Document{nodes: [heading]} = document} =
        Markdown.parse("## :boom: `mysqldump` fails\n", context())

      [_shortcode, code, rest] = heading.nodes

      assert HeadingIdentifiers.run(document) ==
               %{
                 document
                 | nodes: [
                     %{
                       heading
                       | nodes: [%MDEx.HtmlInline{literal: ":boom: "}, code, rest]
                     }
                   ]
               }
    end

    test "leaves a heading of nothing but a shortcode as it is" do
      {:ok, document} = Markdown.parse("## :tada:\n", context())

      assert HeadingIdentifiers.run(document) == document
    end

    test "leaves a heading written with no shortcode as it is" do
      {:ok, document} = Markdown.parse("## Create your server\n", context())

      assert HeadingIdentifiers.run(document) == document
    end

    test "leaves the words a heading writes between colons alone" do
      {:ok, document} = Markdown.parse("## Meeting at 10:30: what to bring\n", context())

      assert HeadingIdentifiers.run(document) == document
    end

    test "leaves a shortcode written as code in a heading alone" do
      {:ok, document} = Markdown.parse("## Writing `:books:` in a page\n", context())

      assert HeadingIdentifiers.run(document) == document
    end

    test "leaves the shortcodes of everything that is not a heading alone" do
      {:ok, document} = Markdown.parse(":exclamation: A task you must perform.\n", context())

      assert HeadingIdentifiers.run(document) == document
    end
  end

  defp context, do: CourseSiteFactory.build(:render_context)
end
