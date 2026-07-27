defmodule ArchiDep.CourseSite.HeadingsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.Headings

  @exercise {:document, DocumentRef.new(402, "run-virtual-server", :exercise)}
  @cheatsheet {:cheatsheet, "sysadmin"}

  describe "new/1" do
    test "holds the identifiers read off each page" do
      pages = %{@exercise => ["create-your-server"], @cheatsheet => ["how-do-i-commit"]}

      assert Headings.new(pages) == %Headings{pages: pages}
    end

    test "holds no page at all" do
      assert Headings.new(%{}) == %Headings{pages: %{}}
    end
  end

  describe "fetch/3" do
    test "finds a heading of a page" do
      assert Headings.fetch(headings(), @exercise, "configure-open-ports") ==
               {:ok, %HeadingRef{page: @exercise, id: "configure-open-ports"}}
    end

    test "does not find a heading the page does not have" do
      assert Headings.fetch(headings(), @exercise, "configure-closed-ports") == :error
    end

    test "does not find a heading of another page" do
      assert Headings.fetch(headings(), @cheatsheet, "configure-open-ports") == :error
    end

    test "does not find a heading of a page that was never read" do
      assert Headings.fetch(headings(), :home, "create-your-server") == :error
    end
  end

  describe "heading!/3" do
    test "finds a heading of a page" do
      assert Headings.heading!(headings(), @cheatsheet, "how-do-i-change-my-username-usermod") ==
               %HeadingRef{page: @cheatsheet, id: "how-do-i-change-my-username-usermod"}
    end

    test "refuses a heading the page does not have, offering the ones closest to it" do
      assert_raise ArgumentError,
                   "/course/402-run-virtual-server/ has no configure-open-port heading; " <>
                     "did you mean configure-open-ports?",
                   fn -> Headings.heading!(headings(), @exercise, "configure-open-port") end
    end

    test "refuses a heading that resembles nothing the page has, offering nothing" do
      assert_raise ArgumentError,
                   "/course/402-run-virtual-server/ has no swap heading",
                   fn -> Headings.heading!(headings(), @exercise, "swap") end
    end

    test "refuses a page that was never read" do
      assert_raise ArgumentError,
                   "No headings were read for /",
                   fn -> Headings.heading!(headings(), :home, "create-your-server") end
    end
  end

  defp headings,
    do:
      Headings.new(%{
        @exercise => [
          "create-your-server",
          "configure-open-ports",
          "add-swap-space-to-your-virtual-server"
        ],
        @cheatsheet => ["how-do-i-change-my-username-usermod"]
      })
end
