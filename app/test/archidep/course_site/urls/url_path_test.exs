defmodule ArchiDep.CourseSite.Urls.UrlPathTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Urls.UrlPath

  doctest ArchiDep.CourseSite.Urls.UrlPath

  describe "normalize/1" do
    test "resolves the root" do
      assert UrlPath.normalize("/") == {:ok, "/"}
    end

    test "resolves a path that climbs back to the root" do
      assert UrlPath.normalize("/cheatsheets/git/../../") == {:ok, "/"}
    end

    test "resolves consecutive parent segments" do
      assert UrlPath.normalize("/course/104-ssh/slides/../../images/tunnel.png") ==
               {:ok, "/course/images/tunnel.png"}
    end

    test "collapses empty segments" do
      assert UrlPath.normalize("/course//204-hello-github//exercise.html") ==
               {:ok, "/course/204-hello-github/exercise.html"}
    end

    test "keeps a trailing slash when the last segment is a parent reference" do
      assert UrlPath.normalize("/course/301-nginx/slides/..") == {:ok, "/course/301-nginx/"}
    end

    test "reports a path climbing above the root" do
      assert UrlPath.normalize("/../assets/theme.css") == {:error, :escapes_root}
    end

    test "reports a path climbing above the root after resolving segments" do
      assert UrlPath.normalize("/cheatsheets/docker/../../../images/whale.png") ==
               {:error, :escapes_root}
    end

    property "is idempotent" do
      check all path <- absolute_path() do
        case UrlPath.normalize(path) do
          {:ok, normalized} -> assert UrlPath.normalize(normalized) == {:ok, normalized}
          {:error, :escapes_root} -> assert UrlPath.normalize(path) == {:error, :escapes_root}
        end
      end
    end
  end

  describe "dirname/1" do
    test "returns an empty string for a bare filename" do
      assert UrlPath.dirname("whale.png") == ""
    end

    test "returns nested directories" do
      assert UrlPath.dirname("slides/images/tty.jpg") == "slides/images/"
    end

    test "returns a lone parent reference" do
      assert UrlPath.dirname("../nano.png") == "../"
    end
  end

  describe "encode/1" do
    test "encodes characters that are not allowed in a URL path" do
      assert UrlPath.encode("ArchiDep 402 - Cloud & Deployment.pdf") ==
               "ArchiDep%20402%20-%20Cloud%20%26%20Deployment.pdf"
    end

    test "leaves separators and unreserved characters intact" do
      assert UrlPath.encode("pdf/archi-dep_402.~final.pdf") == "pdf/archi-dep_402.~final.pdf"
    end
  end

  describe "insert_suffix/2" do
    test "appends the suffix to a dotfile, which has no extension" do
      assert UrlPath.insert_suffix(".gitignore", "d41d8c") == ".gitignore-d41d8c"
    end

    test "inserts the suffix into a name containing directories" do
      assert UrlPath.insert_suffix("search/lunr.json", "d41d8c") == "search/lunr-d41d8c.json"
    end
  end

  defp absolute_path do
    gen all segments <- list_of(one_of([constant("."), constant(".."), string(:alphanumeric)])),
            trailing_slash? <- boolean() do
      "/" <> Enum.join(segments, "/") <> if trailing_slash?, do: "/", else: ""
    end
  end
end
