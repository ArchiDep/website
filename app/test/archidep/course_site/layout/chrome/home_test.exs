defmodule ArchiDep.CourseSite.Layout.Chrome.HomeTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 1, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Home
  alias ArchiDep.CourseSite.Layout.Chrome.HomeCard
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry

  @links %{logo: "/favicons/archidep-512-flat.png", heig_logo: "/favicons/heig.png"}

  describe "title/1" do
    test "names the course, who teaches it, and how it is doing" do
      assert render(&Home.title/1, %{links: @links, badges?: true}) ==
               expected_title(badges: badges_markup())
    end

    test "keeps the licence but drops what reports on the live site" do
      assert render(&Home.title/1, %{links: @links, badges?: false}) ==
               expected_title(badges: "\n        ")
    end
  end

  describe "welcome/1" do
    test "greets whoever arrives at the course" do
      assert render(&Home.welcome/1) ==
               String.trim_trailing("""
               <div class="not-prose alert alert-success alert-soft my-4 print:hidden" role="alert">
                 #{icon(:information_circle, "size-6 stroke-success shrink-0")}
                 <span>Welcome to the Architecture &amp; Deployment course!</span>
               </div>
               """)
    end
  end

  describe "cards/1" do
    test "shows what was covered, what is due and what the next session covers" do
      cards = [
        %HomeCard{kind: :previously, entries: [entry("/course/507-dns/", "DNS")]},
        %HomeCard{kind: :due_next, entries: [entry("/course/508-tls/", "TLS")]},
        %HomeCard{
          kind: :next_time,
          entries: [entry("/course/600-git-hooks/", "Git Hooks"), entry("/course/601-ci/", "CI")]
        }
      ]

      assert render(&Home.cards/1, %{cards: cards}) ==
               expected_cards([
                 card_markup(
                   "Previously",
                   "bg-success text-success-content",
                   "hover:bg-success-content/10",
                   "hover:!text-success-content",
                   [{"/course/507-dns/", "DNS"}]
                 ),
                 card_markup(
                   "Due next",
                   "bg-warning text-warning-content",
                   "hover:bg-warning-content/10",
                   "hover:!text-warning-content",
                   [{"/course/508-tls/", "TLS"}]
                 ),
                 card_markup(
                   "Next time",
                   "bg-info text-info-content",
                   "hover:bg-info-content/10",
                   "hover:!text-info-content",
                   [{"/course/600-git-hooks/", "Git Hooks"}, {"/course/601-ci/", "CI"}]
                 )
               ])
    end

    test "draws nothing at all for a course with nothing to say about where it is" do
      assert render(&Home.cards/1, %{cards: []}) == ""
    end
  end

  defp entry(url, title),
    do: %MenuEntry{
      url: url,
      title: title,
      emoji_html: "<E:book>",
      deck_emoji_html: nil,
      status: :done,
      current?: false,
      deck?: false
    }

  ## What the cards should draw. The row indents the first card it holds and
  ## the first line of each, and every one after that follows its predecessor
  ## directly: HEEx writes the whitespace around a repeated element once.

  defp expected_cards(cards) do
    String.trim_trailing("""
    <div class="not-prose my-4 grid grid-cols-1 xl:grid-cols-3 gap-4 print:hidden">
      #{Enum.join(cards)}
    </div>
    """)
  end

  defp card_markup(title, card_class, line_class, link_class, entries) do
    ~s(<div class="card card-sm 2xl:card-md #{card_class}">\n) <>
      ~s(    <div class="card-body">\n) <>
      ~s(      <p class="card-title font-title text-2xl mt-0 flex-none">\n) <>
      ~s(        #{title}\n) <>
      ~s(      </p>\n) <>
      ~s(      <ul class="flex flex-col gap-y-1">\n) <>
      ~s(        ) <>
      Enum.map_join(entries, fn {url, name} -> line_markup(url, name, line_class, link_class) end) <>
      ~s(\n      </ul>\n) <>
      ~s(    </div>\n) <>
      ~s(  </div>)
  end

  defp line_markup(url, name, line_class, link_class) do
    ~s(<li class="px-2 py-1 rounded-full #{line_class}">\n) <>
      ~s(          <a href="#{url}" class="#{link_class}">\n) <>
      ~s(            #{title_markup(name)}\n) <>
      ~s(          </a>\n) <>
      ~s(        </li>)
  end

  defp title_markup(name),
    do:
      ~s(<span class="flex items-center gap-x-2">\n) <>
        ~s(  <span class="size-4"><E:book></span>\n) <>
        ~s(  <span>#{name}</span>\n) <>
        ~s(</span>)

  defp expected_title(parts) do
    String.trim_trailing("""
    <div class="flex flex-wrap xs:flex-nowrap items-center gap-4">
      <div class="flex items-center gap-4">
        <img src="/favicons/archidep-512-flat.png" alt="ArchiDep logo" class="!m-0 w-40">
      </div>
      <div>
        <h1 class="text-2xl md:text-2xl lg:text-3xl xl:text-3xl 2xl:text-5xl !mb-0 dark:text-white print:hidden">
          Architecture &amp; Deployment
        </h1>
        <div class="flex flex-wrap 2xl:flex-nowrap items-center gap-x-4 gap-y-2">
          <span class="flex items-center gap-2">
            <a href="https://heig-vd.ch" target="_blank" rel="noopener noreferrer">
              <img src="/favicons/heig.png" alt="HEIG-VD logo" class="!m-0 w-8">
            </a>
            <small class="text-xl font-title whitespace-normal sm:whitespace-nowrap">
              A
              <a href="https://heig-vd.ch/formation/bachelor/ingenierie-des-medias/" class="link hover:text-accent" target="_blank" rel="noopener noreferrer">
                Media Engineering
              </a>
              Course
            </small>
          </span>

          <ul class="not-prose flex flex-wrap md:flex-nowrap items-center gap-2">
            #{Keyword.fetch!(parts, :badges)}
            <li>
              <a href="https://opensource.org/licenses/MIT">
                <img class="!m-0" src="https://img.shields.io/static/v1?label=license&amp;message=MIT&amp;color=informational" alt="MIT License">
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """)
  end

  defp badges_markup, do: Enum.join([status_badge(), build_badge()], "\n        ")

  defp status_badge,
    do: badge("https://status.archidep.ch", status_badge_url(), "Status", "print:hidden")

  defp build_badge,
    do:
      badge(
        "https://github.com/ArchiDep/website/actions/workflows/build.yml",
        "https://github.com/ArchiDep/website/actions/workflows/build.yml/badge.svg",
        "Build",
        "print:hidden"
      )

  defp status_badge_url,
    do:
      "https://status.archidep.ch/badge/_/status?labelColor=&amp;color=&amp;style=flat&amp;label=status"

  defp badge(href, src, alt, class) do
    ~s(<li class="#{class}">\n) <>
      ~s(          <a href="#{href}">\n) <>
      ~s(            <img class="!m-0" src="#{src}" alt="#{alt}">\n) <>
      ~s(          </a>\n) <>
      ~s(        </li>)
  end
end
