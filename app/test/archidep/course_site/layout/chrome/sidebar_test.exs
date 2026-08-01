defmodule ArchiDep.CourseSite.Layout.Chrome.SidebarTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Footer
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias ArchiDep.CourseSite.Layout.Chrome.MenuSection
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Layout.Chrome.Sidebar

  @links %{
    home: "/",
    favicon_192: "/favicons/archidep-rocket-192.png",
    heig_logo: "/favicons/heig.png",
    coffee_logo: "/favicons/archidep-coffee.png",
    repository: "https://github.com/ArchiDep/website"
  }

  describe "sidebar/1" do
    test "lists the course, the page being read marked as where the reader is" do
      assert sidebar([]) ==
               expected(
                 sections: [
                   section_markup(
                     status_class: "course-section-due",
                     fold: :locked_open,
                     entries: [entry_markup(classes: "course-item-due course-item-current")]
                   )
                 ]
               )
    end

    test "folds a section the course has not reached, and lets it be unfolded" do
      section = section(status: :future, open?: false, entries: [entry(current?: false)])

      assert sidebar(sections: [section]) ==
               expected(
                 sections: [
                   section_markup(
                     status_class: "course-section-future",
                     fold: :closed,
                     entries: [entry_markup(classes: "course-item-due")]
                   )
                 ]
               )
    end

    test "opens a folded section holding the page being read" do
      section = section(status: :future, open?: false, entries: [entry(current?: true)])

      assert sidebar(sections: [section]) ==
               expected(
                 sections: [
                   section_markup(
                     status_class: "course-section-future",
                     fold: :open,
                     entries: [entry_markup(classes: "course-item-due course-item-current")]
                   )
                 ]
               )
    end

    test "opens a deck in a tab of its own and says so" do
      section = section(entries: [entry(deck?: true, deck_emoji_html: nil)])

      assert sidebar(sections: [section]) ==
               expected(
                 sections: [
                   section_markup(
                     status_class: "course-section-due",
                     fold: :locked_open,
                     entries: [
                       entry_markup(
                         classes: "course-item-due course-item-current",
                         target: "_blank",
                         deck_emoji: nil,
                         external?: true
                       )
                     ]
                   )
                 ]
               )
    end

    test "marks the cheatsheet being read without claiming the course has reached it" do
      assert sidebar(cheatsheets: [cheatsheet(current?: true)]) ==
               expected(cheatsheets: [cheatsheet_markup(classes: "course-item-current")])
    end

    test "drops the whole menu into the application on a build that cannot reach one" do
      assert sidebar(app_navigation?: false) == expected(app_navigation: "")
    end

    test "marks the home page's own entry when that is what is being read" do
      assert sidebar(home?: true) ==
               expected(app_navigation: app_navigation_markup(home_class: "bg-primary/50 "))
    end
  end

  ## What the sidebar is given.

  defp sidebar(overrides) do
    app_navigation? = Keyword.get(overrides, :app_navigation?, true)

    render(&Sidebar.sidebar/1, %{
      sections: Keyword.get(overrides, :sections, [section()]),
      cheatsheets: Keyword.get(overrides, :cheatsheets, [cheatsheet()]),
      links: @links,
      policy: %Policy{app_navigation?: app_navigation?, account?: true, badges?: true},
      home?: Keyword.get(overrides, :home?, false),
      version: "1.2.3",
      commit: "main@abc1234"
    })
  end

  defp section(overrides \\ []) do
    %MenuSection{
      title: "Networking",
      slug: "networking",
      status: Keyword.get(overrides, :status, :due),
      open?: Keyword.get(overrides, :open?, true),
      entries: Keyword.get(overrides, :entries, [entry()])
    }
  end

  defp entry(overrides \\ []) do
    %MenuEntry{
      url: "/course/507-dns/",
      title: "DNS",
      emoji_html: "<E:book>",
      deck_emoji_html: Keyword.get(overrides, :deck_emoji_html, "<E:clapper>"),
      status: :due,
      current?: Keyword.get(overrides, :current?, true),
      deck?: Keyword.get(overrides, :deck?, false)
    }
  end

  defp cheatsheet(overrides \\ []) do
    %MenuEntry{
      url: "/cheatsheets/git/",
      title: "Git",
      emoji_html: "<E:memo>",
      deck_emoji_html: nil,
      status: nil,
      current?: Keyword.get(overrides, :current?, false),
      deck?: false
    }
  end

  ## What it should draw, stated rather than worked out a second time: every
  ## hole in the markup below is filled by the test that is about it, with what
  ## should come out rather than with what went in.

  defp expected(parts) do
    String.trim_trailing("""
    <div class="w-80 max-w-full bg-base-200 text-base-content min-h-full pb-16">
      <div class="lg:hidden w-full flex justify-between items-center pl-6 pr-2 pt-4">
        <a href="/" class="text-xl font-bold inline">
          <div class="flex items-center gap-x-2">
            <div class="avatar">
              <div class="w-10">
                <img src="/favicons/archidep-rocket-192.png" alt="ArchiDep logo">
              </div>
            </div>
            <span class="font-title">ArchiDep</span>
          </div>
        </a>
        <label for="sidebar" class="btn btn-square btn-ghost">
          #{icon(:x_mark, "size-5")}
        </label>
      </div>
      #{Keyword.get(parts, :app_navigation, app_navigation_markup([]))}
      <ul id="course-material-menu" class="w-full menu px-4 pt-0 pb-4">
        #{Enum.join(Keyword.get(parts, :sections, [section_markup([])]))}
        <li>
          <span class="text-base-content/50 cursor-default">Cheatsheets</span>
        </li>
        #{Enum.join(Keyword.get(parts, :cheatsheets, [cheatsheet_markup([])]), "\n    ")}
      </ul>

      #{footer_markup()}
    </div>
    """)
  end

  defp app_navigation_markup(parts) do
    ~s(<div class="px-4">\n) <>
      ~s(    <ul class="menu menu-horizontal grid grid-cols-5 gap-2">\n) <>
      ~s(      <li>\n) <>
      ~s(        <a href="/" class="#{Keyword.get(parts, :home_class, "")}tooltip tooltip-bottom" data-tip="Course">\n) <>
      ~s(          #{icon(:home, "w-full")}\n) <>
      ~s(          <span class="sr-only">Course</span>\n) <>
      ~s(        </a>\n) <>
      ~s(      </li>\n) <>
      ~s(      <li>\n) <>
      ~s(        <a href="/app" class="tooltip tooltip-bottom" data-tip="Dashboard">\n) <>
      ~s(          #{icon(:cube, "w-full")}\n) <>
      ~s(          <span class="sr-only">Dashboard</span>\n) <>
      ~s(        </a>\n) <>
      ~s(      </li>\n) <>
      ~s(      <li>\n) <>
      ~s(        <a href="/admin" id="sidebar-admin-item" class="hidden tooltip tooltip-bottom" data-tip="Admin">\n) <>
      ~s(          #{icon(:fire, "text-error w-full")}\n) <>
      ~s(          <span class="sr-only">Admin</span>\n) <>
      ~s(        </a>\n) <>
      ~s(      </li>\n) <>
      ~s(    </ul>\n) <>
      ~s(  </div>)
  end

  defp section_markup(parts) do
    fold = Keyword.get(parts, :fold, :locked_open)

    ~s(\n      <li class="peer/section-0 group/section-0 #{Keyword.get(parts, :status_class, "course-section-due")}">\n) <>
      ~s(        <label for="section-networking-toggle" class="flex justify-between items-center">\n) <>
      ~s(          <span class="text-base-content/50 cursor-default">Networking</span>\n) <>
      chevrons_markup(fold) <>
      ~s(          <input type="checkbox" id="section-networking-toggle" class="hidden"#{checked_markup(fold)}>\n) <>
      ~s(        </label>\n) <>
      ~s(      </li>) <>
      Enum.join(Keyword.get(parts, :entries, [entry_markup([])])) <>
      ~s(\n    )
  end

  # A section nobody can fold shows no arrow to fold it with, leaving the blank
  # lines its two unwritten elements leave.
  defp chevrons_markup(:locked_open), do: "          \n          \n"

  defp chevrons_markup(_foldable),
    do:
      ~s(          <span class="group-has-checked/section-0:hidden">\n) <>
        ~s(            #{icon(:chevron_down, "size-4 text-base-content/50")}\n) <>
        ~s(          </span>\n) <>
        ~s(          <span class="hidden group-has-checked/section-0:inline">\n) <>
        ~s(            #{icon(:chevron_up, "size-4 text-base-content/50")}\n) <>
        ~s(          </span>\n)

  defp checked_markup(:locked_open), do: " checked disabled"
  defp checked_markup(:open), do: " checked"
  defp checked_markup(:closed), do: ""

  defp entry_markup(parts) do
    ~s(\n      <li class="group hidden peer-has-checked/section-0:flex #{Keyword.get(parts, :classes, "course-item-due course-item-current")}">\n) <>
      ~s(        <a href="/course/507-dns/" target="#{Keyword.get(parts, :target, "_self")}" class="flex items-center gap-2">\n) <>
      ~s(          #{title_markup("<E:book>", "DNS")}\n) <>
      deck_emoji_markup(Keyword.get(parts, :deck_emoji, "<E:clapper>")) <>
      external_markup(Keyword.get(parts, :external?, false)) <>
      ~s(        </a>\n) <>
      ~s(      </li>)
  end

  defp cheatsheet_markup(parts) do
    ~s(<li class="#{Keyword.get(parts, :classes, "")}">\n) <>
      ~s(      <a href="/cheatsheets/git/" class="flex items-center gap-2">\n) <>
      ~s(        #{title_markup("<E:memo>", "Git")}\n) <>
      ~s(      </a>\n) <>
      ~s(    </li>)
  end

  defp title_markup(emoji, title),
    do:
      ~s(<span class="flex items-center gap-x-2">\n) <>
        ~s(  <span class="size-4">#{emoji}</span>\n) <>
        ~s(  <span>#{title}</span>\n) <>
        ~s(</span>)

  defp deck_emoji_markup(nil), do: "          \n"
  defp deck_emoji_markup(html), do: ~s(          <span>#{html}</span>\n)

  defp external_markup(false), do: "          \n"

  defp external_markup(true),
    do:
      ~s(          #{icon(:arrow_top_right_on_square, "size-4 text-base-content/25 group-hover:text-base-content/75")}\n)

  # What the footer draws is pinned by the footer's own test; what this one is
  # about is that the navigation ends with it.
  defp footer_markup do
    %{
      links: @links,
      policy: %Policy{app_navigation?: true, account?: true, badges?: true},
      version: "1.2.3",
      commit: "main@abc1234",
      __changed__: nil
    }
    |> Footer.footer()
    |> Html.render()
  end
end
