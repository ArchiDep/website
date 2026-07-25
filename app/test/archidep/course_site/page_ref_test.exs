defmodule ArchiDep.CourseSite.PageRefTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.Support.CourseSiteFactory

  doctest ArchiDep.CourseSite.PageRef

  describe "output_path/1" do
    test "returns the path of a subject" do
      subject = DocumentRef.new(507, "dns", :subject)

      assert PageRef.output_path({:document, subject}) == "/course/507-dns/"
    end

    test "returns the path of an exercise" do
      exercise = DocumentRef.new(514, "certbot-deployment", :exercise)

      assert PageRef.output_path({:document, exercise}) == "/course/514-certbot-deployment/"
    end

    test "returns the path of slides, one segment below the chapter" do
      slides = DocumentRef.new(203, "git-collaboration", :slides)

      assert PageRef.output_path({:document, slides}) == "/course/203-git-collaboration/slides/"
    end
  end

  describe "identity/1" do
    test "returns the identity of the home page" do
      assert PageRef.identity(:home) == :home
    end

    test "returns the identity of a cheatsheet" do
      assert PageRef.identity({:cheatsheet, "command-line"}) == {:cheatsheet, "command-line"}
    end
  end

  describe "parse_output_path/1" do
    test "parses the home page" do
      assert PageRef.parse_output_path("/") == {:ok, :home}
    end

    test "rejects a path missing its trailing slash" do
      assert PageRef.parse_output_path("/course/704-render-deployment") ==
               {:error, {:invalid_output_path, "/course/704-render-deployment"}}
    end

    test "rejects a path below a chapter's slides" do
      assert PageRef.parse_output_path("/course/101-command-line/slides/images/") ==
               {:error, {:invalid_output_path, "/course/101-command-line/slides/images/"}}
    end

    test "rejects an unversioned path outside the course material" do
      assert PageRef.parse_output_path("/assets/theme/theme.css") ==
               {:error, {:invalid_output_path, "/assets/theme/theme.css"}}
    end

    property "recovers the identity a page's path preserves" do
      check all page <- CourseSiteFactory.page_ref_generator() do
        assert page |> PageRef.output_path() |> PageRef.parse_output_path() ==
                 {:ok, PageRef.identity(page)}
      end
    end
  end
end
