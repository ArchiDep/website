defmodule ArchiDep.CourseSite.Layout.Chrome.BannerTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Banner

  @live_site "https://archidep.ch/2026/course/104-ssh/"
  @current_edition "https://archidep.ch/latest?to=/2025/course/104-ssh/"

  describe "banner/1" do
    test "sends a reader of the backup copy to the same page of the site it stands in for" do
      assert banner(:backup, @live_site) ==
               expected_bar(
                 @live_site,
                 "You are reading the backup copy of the ArchiDep website.",
                 "Go to the live site."
               )
    end

    test "sends a reader of a past edition to whatever supersedes the page they are on" do
      assert banner(:archive, @current_edition) ==
               expected_bar(
                 @current_edition,
                 "This is the archived 2025-2026 edition of the course.",
                 "Go to the current version of this page."
               )
    end
  end

  describe "corner/1" do
    test "says the same of the backup copy in the corner of a deck" do
      assert corner(:backup, @live_site) ==
               expected_badge(@live_site, "Backup copy", "Go to the live site.")
    end

    test "says the same of a past edition in the corner of a deck" do
      assert corner(:archive, @current_edition) ==
               expected_badge(@current_edition, "Archived edition", "Go to the current version.")
    end
  end

  defp banner(kind, url),
    do: render(&Banner.banner/1, %{kind: kind, url: url, years: "2025-2026"})

  defp corner(kind, url), do: render(&Banner.corner/1, %{kind: kind, url: url})

  defp expected_bar(url, statement, call_to_action) do
    String.trim_trailing("""
    <div role="alert" class="alert alert-warning alert-soft rounded-none flex flex-wrap justify-center text-center gap-x-2 print:hidden">
      <span>#{statement}</span>
      <a href="#{url}" class="link font-semibold transition-colors hover:text-base-content">
        #{call_to_action}
      </a>
    </div>
    """)
  end

  defp expected_badge(url, label, tooltip) do
    String.trim_trailing("""
    <a href="#{url}" class="tooltip print:hidden" data-tip="#{tooltip}">
      <span class="badge badge-warning badge-sm">#{label}</span>
    </a>
    """)
  end
end
