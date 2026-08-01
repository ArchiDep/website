defmodule ArchiDep.CourseSite.Layout.Chrome.HomeTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 1, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Home

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
