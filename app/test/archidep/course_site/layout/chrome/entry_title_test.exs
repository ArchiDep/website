defmodule ArchiDep.CourseSite.Layout.Chrome.EntryTitleTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.EntryTitle
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry

  describe "entry_title/1" do
    test "names a line of the course after the picture of what it is" do
      assert render(&EntryTitle.entry_title/1, %{entry: entry()}) ==
               String.trim_trailing("""
               <span class="flex items-center gap-x-2">
                 <span class="size-4"><E:book></span>
                 <span>Domain Name System (DNS)</span>
               </span>
               """)
    end

    test "says what a chapter is called rather than what a browser would make of it" do
      assert render(&EntryTitle.entry_title/1, %{entry: entry(title: "Git & GitHub")}) ==
               String.trim_trailing("""
               <span class="flex items-center gap-x-2">
                 <span class="size-4"><E:book></span>
                 <span>Git &amp; GitHub</span>
               </span>
               """)
    end
  end

  defp entry(overrides \\ []) do
    %MenuEntry{
      url: "/course/507-dns/",
      title: Keyword.get(overrides, :title, "Domain Name System (DNS)"),
      emoji_html: "<E:book>",
      deck_emoji_html: nil,
      status: :due,
      current?: false,
      deck?: false
    }
  end
end
