defmodule ArchiDep.CourseSite.Layout.Chrome.HeaderTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [icon: 2, render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Header
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.SiteInfo

  @links %{
    home: "/",
    favicon_192: "/favicons/archidep-rocket-192.png",
    branch: "https://github.com/ArchiDep/website/tree/main",
    source: "https://github.com/ArchiDep/website/blob/abc123/course/index.md"
  }

  describe "header/1" do
    test "offers the way in and out of an account on the live site" do
      assert header(account?: true) == expected([])
    end

    test "offers neither on a build that cannot reach the application" do
      assert header(account?: false) == expected(account: "\n    ")
    end

    test "prints neither branch nor revision for a checkout that can name neither" do
      assert header(account?: true, links: Map.drop(@links, [:branch, :source])) ==
               expected(branch: "\n      ", revision: "\n    ")
    end
  end

  defp header(overrides) do
    account? = Keyword.fetch!(overrides, :account?)

    render(&Header.header/1, %{
      links: Keyword.get(overrides, :links, @links),
      policy: %Policy{app_navigation?: account?, account?: account?, badges?: account?},
      site:
        SiteInfo.new(
          version: "1.2.3",
          git_branch: "main",
          git_revision: "abc123",
          years: "2025-2026",
          years_short: "25-26"
        )
    })
  end

  defp expected(parts) do
    String.trim_trailing("""
    <header class="navbar bg-base-300 screen:shadow-sm w-full">
      <div class="navbar-start">
        <label for="sidebar" class="lg:hidden print:hidden btn btn-square btn-ghost">
          #{icon(:bars_3, "size-5")}
        </label>
        <a class="btn btn-ghost text-xl print:text-3xl print:pl-0" href="/">
          <div class="flex items-center gap-x-2">
            <div class="avatar">
              <div class="w-10">
                <img src="/favicons/archidep-rocket-192.png" alt="ArchiDep logo">
              </div>
            </div>
            <h1 class="print:hidden">ArchiDep</h1>
            <h1 class="hidden print:block">Architecture &amp; Deployment</h1>
          </div>
        </a>
      </div>

      <div class="navbar-end flex gap-2 print:hidden">
        <button type="button" id="search-button" class="hidden btn btn-ghost max-sm:btn-circle hover:bg-neutral">
          #{icon(:magnifying_glass, "size-4 sm:size-6")}
          <kbd class="kbd kbd-xs sm:kbd-sm macos hidden">⌘K</kbd>
          <kbd class="kbd kbd-xs sm:kbd-sm hidden sm:inline">Ctrl K</kbd>
        </button>
        #{Keyword.get(parts, :account, account_markup())}
      </div>
    </header>

    <div class="hidden print:block w-full">
      <ul class="list-none m-0 p-0 flex flex-wrap gap-2 text-xs text-base-content/50">
        <li>2025-2026</li>
        <li>
          v1.2.3#{Keyword.get(parts, :branch, branch_markup(@links[:branch]))}
        </li>#{Keyword.get(parts, :revision, revision_markup(@links[:source]))}
      </ul>
    </div>
    """)
  end

  defp account_markup do
    ~s(<a href="/auth/switch-edu-id/configure?to=%2F" id="login-button" class="hidden btn btn-ghost p-2">\n) <>
      ~s(      #{icon(:arrow_right_end_on_rectangle, "size-4 sm:size-6")}\n) <>
      ~s(      <span class="sr-only">Log in</span>\n) <>
      ~s(    </a>\n) <>
      profile()
  end

  defp profile do
    ~s(    <div id="navbar-profile" class="hidden dropdown dropdown-end">\n) <>
      ~s(      <button type="button" class="btn btn-ghost btn-circle hover:bg-neutral">\n) <>
      ~s(        <div class="user hidden w-6 sm:w-8 rounded-full">\n) <>
      ~s(          #{icon(:user_circle, "w-full")}\n) <>
      ~s(        </div>\n) <>
      ~s(        <div class="impersonator hidden w-6 sm:w-8 rounded-full">\n) <>
      ~s(          #{icon(:eye, "w-full")}\n) <>
      ~s(        </div>\n) <>
      ~s(      </button>\n) <>
      ~s(      <ul class="menu menu-sm dropdown-content bg-base-300 rounded-box z-1 mt-3 w-52 p-2 shadow">\n) <>
      ~s(        <li>\n) <>
      ~s(          <a href="/profile" class="flex items-center gap-1">\n) <>
      ~s(            #{icon(:user, "size-3.5")}\n) <>
      ~s(            <span>Profile</span>\n) <>
      ~s(          </a>\n) <>
      ~s(        </li>\n) <>
      ~s(        <li>\n) <>
      ~s(          <button type="button" id="logout-button" class="flex items-center gap-1" disabled>\n) <>
      ~s(            #{icon(:arrow_right_start_on_rectangle, "size-3.5")}\n) <>
      ~s(            <span>Log out</span>\n) <>
      ~s(          </button>\n) <>
      ~s(        </li>\n) <>
      ~s(      </ul>\n) <>
      ~s(    </div>)
  end

  defp branch_markup(url),
    do: ~s(\n      <span>\n        on branch <a href="#{url}">main</a>\n      </span>)

  defp revision_markup(url),
    do: ~s(\n    <li>\n      <a href="#{url}">Rev: abc123</a>\n    </li>)
end
