defmodule ArchiDep.CourseSite.Layout.Chrome.FooterTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Layout.Chrome.Footer
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.SiteInfo

  @links %{
    coffee_1x: "/favicons/archidep-coffee-1x.webp",
    coffee_2x: "/favicons/archidep-coffee-2x.webp",
    coffee_3x: "/favicons/archidep-coffee-3x.webp",
    coffee_still_1x: "/favicons/archidep-coffee-1x.png",
    coffee_still_2x: "/favicons/archidep-coffee-2x.png",
    coffee_still_3x: "/favicons/archidep-coffee-3x.png",
    heig_logo: "/favicons/heig.png",
    coffee_logo: "/favicons/archidep-coffee.png",
    repository: "https://github.com/ArchiDep/website",
    home: "/"
  }

  describe "footer/1" do
    test "says who the course belongs to and which build this is" do
      assert render(commit: "main@abc1234") ==
               expected_footer(version: version_markup(commit: "main@abc1234"))
    end

    test "shows the release alone when the checkout could name no commit" do
      assert render([]) == expected_footer(version: version_markup(commit: nil))
    end

    test "leaves out the status badge in a build that is not the live site" do
      assert render(
               policy: %Policy{
                 app_navigation?: false,
                 account?: false,
                 badges?: false,
                 progress_cards?: false
               }
             ) ==
               expected_footer(status_badge: "", version: version_markup(commit: nil))
    end
  end

  describe "commit/1" do
    test "names the branch and enough of the revision to recognise it by" do
      assert Footer.commit(site(git_branch: "main", git_revision: "abc1234def")) == "main@abc1234"
    end

    test "says nothing for a checkout that cannot name its branch" do
      assert Footer.commit(site(git_branch: nil, git_revision: "abc1234def")) == nil
    end

    test "says nothing for a checkout that cannot name its revision" do
      assert Footer.commit(site(git_branch: "main", git_revision: nil)) == nil
    end
  end

  defp render(overrides) do
    [
      links: @links,
      policy: %Policy{app_navigation?: true, account?: true, badges?: true, progress_cards?: true},
      version: "1.2.3"
    ]
    |> Keyword.merge(overrides)
    |> Map.new()
    |> Footer.footer()
    |> Html.render()
  end

  defp site(overrides) do
    [version: "1.2.3", years: "2025-2026", years_short: "25-26"]
    |> Keyword.merge(overrides)
    |> SiteInfo.new()
  end

  defp expected_footer(parts) do
    String.trim_trailing("""
    <footer class="p-4 absolute bottom-0 left-0 right-0 border-t border-black/10 dark:border-white/10">
      <div class="flex justify-between items-center gap-2">
        <p class="flex items-center gap-2">
          <a href="https://heig-vd.ch/" target="_blank" rel="noopener noreferrer">
            <img src="/favicons/heig.png" alt="HEIG-VD logo" class="!m-0 w-8">
          </a>
          #{Keyword.get(parts, :status_badge, status_badge_markup())}
          <a href="https://github.com/ArchiDep/website" target="_blank" rel="noopener noreferrer">
            #{github_icon()}
          </a>
        </p>
        <p class="flex items-center gap-x-1 text-xs">
          <a href="/" class="hover:text-accent flex items-center gap-1.5">
            <picture class="-mt-1">
              <source media="(prefers-reduced-motion: reduce)" type="image/png" srcset="/favicons/archidep-coffee-1x.png 1x, /favicons/archidep-coffee-2x.png 2x, /favicons/archidep-coffee-3x.png 3x">
              <img src="/favicons/archidep-coffee-1x.png" srcset="/favicons/archidep-coffee-1x.webp 1x, /favicons/archidep-coffee-2x.webp 2x, /favicons/archidep-coffee-3x.webp 3x" width="27" height="31" alt="ArchiDep logo" class="w-[27px] [image-rendering:pixelated]">
            </picture>
            <span class="font-title">ArchiDep</span>
          </a>
          #{Keyword.fetch!(parts, :version)}
        </p>
      </div>
    </footer>
    """)
  end

  # Whichever of the two the build has, the other leaves the blank line an
  # unwritten element leaves behind.
  defp version_markup(commit: nil), do: ~s(\n      <span class="font-title">1.2.3</span>)

  defp version_markup(commit: commit),
    do: """
    <span class="tooltip tooltip-left">
            <span class="tooltip-content">#{commit}</span>
            <span class="font-title">1.2.3</span>
          </span>
          \
    """

  defp status_badge_markup,
    do: """
    <a href="https://status.archidep.ch" target="_blank" rel="noopener noreferrer">
            <img src="https://status.archidep.ch/badge/_/dot" alt="Status">
          </a>\
    """

  defp github_icon, do: %{class: "size-4"} |> Icons.github() |> Html.render()
end
