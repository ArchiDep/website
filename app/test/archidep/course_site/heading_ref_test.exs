defmodule ArchiDep.CourseSite.HeadingRefTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.HeadingRef

  doctest ArchiDep.CourseSite.HeadingRef

  describe "new/2" do
    test "builds a reference to a heading of a course document" do
      page = {:document, DocumentRef.new(402, "run-virtual-server", :exercise)}

      assert HeadingRef.new(page, "create-your-server") ==
               %HeadingRef{page: page, id: "create-your-server"}
    end

    test "builds a reference to a heading of a cheatsheet" do
      assert HeadingRef.new({:cheatsheet, "git"}, "how-do-i-commit") ==
               %HeadingRef{page: {:cheatsheet, "git"}, id: "how-do-i-commit"}
    end

    test "builds a reference to a heading of the home page" do
      assert HeadingRef.new(:home, "what-you-will-learn") ==
               %HeadingRef{page: :home, id: "what-you-will-learn"}
    end
  end
end
