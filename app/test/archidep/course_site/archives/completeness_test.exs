defmodule ArchiDep.CourseSite.Archives.CompletenessTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Archives.Completeness

  @moduletag :tmp_dir

  # Two finished editions and the one being taught, each with a couple of pages,
  # which is enough for every distinction this makes: an edition that is held, one
  # that is not, and the one that is never looked for.
  @editions %{
    "2023" => ["/2023/", "/2023/course/101-command-line/"],
    "2024" => ["/2024/", "/2024/cheatsheets/git/"],
    "2025" => ["/2025/", "/2025/course/101-command-line/"]
  }

  describe "check/3" do
    test "finds every edition a host holds", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, [
        "/2023/",
        "/2023/course/101-command-line/",
        "/2024/",
        "/2024/cheatsheets/git/"
      ])

      assert Completeness.check(tmp_dir, @editions, "2025") == %Completeness{
               directory: {:present, tmp_dir},
               rendered_edition: "2025",
               expected: ["2023", "2024"],
               missing: %{}
             }
    end

    test "names the pages of an edition a host does not hold", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, ["/2023/", "/2024/", "/2024/cheatsheets/git/"])

      assert Completeness.check(tmp_dir, @editions, "2025") == %Completeness{
               directory: {:present, tmp_dir},
               rendered_edition: "2025",
               expected: ["2023", "2024"],
               missing: %{"2023" => ["/2023/course/101-command-line/"]}
             }
    end

    test "never looks for the edition this deployment renders itself", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, [
        "/2023/",
        "/2023/course/101-command-line/",
        "/2024/",
        "/2024/cheatsheets/git/"
      ])

      assert Completeness.check(tmp_dir, @editions, "2024") == %Completeness{
               directory: {:present, tmp_dir},
               rendered_edition: "2024",
               expected: ["2023", "2025"],
               missing: %{"2025" => ["/2025/", "/2025/course/101-command-line/"]}
             }
    end

    test "asks nothing of a host whose only archived edition is the one it renders", %{
      tmp_dir: tmp_dir
    } do
      assert Completeness.check(tmp_dir, %{"2025" => ["/2025/"]}, "2025") == %Completeness{
               directory: {:present, tmp_dir},
               rendered_edition: "2025",
               expected: [],
               missing: %{}
             }
    end

    test "says so when the directory the editions should be in is not there", %{tmp_dir: tmp_dir} do
      absent = Path.join(tmp_dir, "never-cloned")

      assert Completeness.check(absent, @editions, "2025") == %Completeness{
               directory: {:missing, absent},
               rendered_edition: "2025",
               expected: ["2023", "2024"],
               missing: %{}
             }
    end

    test "says so when no directory is configured at all" do
      assert Completeness.check(nil, @editions, "2025") == %Completeness{
               directory: :unconfigured,
               rendered_edition: "2025",
               expected: ["2023", "2024"],
               missing: %{}
             }
    end

    test "takes a page for held only where the page itself is", %{tmp_dir: tmp_dir} do
      # The directory of a page with no index.html in it, which is what a
      # half-synced edition looks like.
      File.mkdir_p!(Path.join(tmp_dir, "2023/course/101-command-line"))
      hold(tmp_dir, ["/2023/", "/2024/", "/2024/cheatsheets/git/"])

      assert Completeness.check(tmp_dir, @editions, "2025") == %Completeness{
               directory: {:present, tmp_dir},
               rendered_edition: "2025",
               expected: ["2023", "2024"],
               missing: %{"2023" => ["/2023/course/101-command-line/"]}
             }
    end
  end

  describe "complete?/1" do
    test "is true of a host holding every edition it must", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, [
        "/2023/",
        "/2023/course/101-command-line/",
        "/2024/",
        "/2024/cheatsheets/git/"
      ])

      assert Completeness.complete?(Completeness.check(tmp_dir, @editions, "2025")) == true
    end

    test "is true of a host with nothing to hold", %{tmp_dir: tmp_dir} do
      assert Completeness.complete?(Completeness.check(tmp_dir, %{"2025" => ["/2025/"]}, "2025")) ==
               true
    end

    test "is false of a host missing one page of one edition", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, ["/2023/", "/2024/", "/2024/cheatsheets/git/"])

      assert Completeness.complete?(Completeness.check(tmp_dir, @editions, "2025")) == false
    end

    test "is false of a host whose editions directory is not there", %{tmp_dir: tmp_dir} do
      assert Completeness.complete?(
               Completeness.check(Path.join(tmp_dir, "never-cloned"), @editions, "2025")
             ) == false
    end

    test "is false of a host that does not say where its editions are" do
      assert Completeness.complete?(Completeness.check(nil, @editions, "2025")) == false
    end
  end

  describe "problems/1" do
    test "says nothing of a host holding every edition it must", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, [
        "/2023/",
        "/2023/course/101-command-line/",
        "/2024/",
        "/2024/cheatsheets/git/"
      ])

      assert Completeness.problems(Completeness.check(tmp_dir, @editions, "2025")) == []
    end

    test "says nothing of a host with nothing to hold" do
      assert Completeness.problems(Completeness.check(nil, %{"2025" => ["/2025/"]}, "2025")) == []
    end

    test "names each incomplete edition, how much of it is missing and where from", %{
      tmp_dir: tmp_dir
    } do
      hold(tmp_dir, ["/2024/cheatsheets/git/"])

      assert Completeness.problems(Completeness.check(tmp_dir, @editions, "2025")) == [
               "Edition 2023 is missing 2 pages from #{tmp_dir}: /2023/, /2023/course/101-command-line/",
               "Edition 2024 is missing 1 page from #{tmp_dir}: /2024/"
             ]
    end

    test "names at most three of the pages of a wholly absent edition", %{tmp_dir: tmp_dir} do
      editions = %{"2023" => Enum.map(1..7, &"/2023/course/#{&1}/"), "2025" => ["/2025/"]}

      assert Completeness.problems(Completeness.check(tmp_dir, editions, "2025")) == [
               "Edition 2023 is missing 7 pages from #{tmp_dir}: /2023/course/1/, /2023/course/2/, /2023/course/3/ and 4 more"
             ]
    end

    test "names the directory that is not there rather than every page in it", %{tmp_dir: tmp_dir} do
      absent = Path.join(tmp_dir, "never-cloned")

      assert Completeness.problems(Completeness.check(absent, @editions, "2025")) == [
               "Editions 2023, 2024 must be served from #{absent}, which does not exist"
             ]
    end

    test "says a host serving editions has nowhere to serve them from" do
      assert Completeness.problems(Completeness.check(nil, @editions, "2025")) == [
               "Editions 2023, 2024 must be served from this host, which has no archives directory"
             ]
    end
  end

  describe "summary/1" do
    test "names the editions held when there is nothing wrong", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, [
        "/2023/",
        "/2023/course/101-command-line/",
        "/2024/",
        "/2024/cheatsheets/git/"
      ])

      assert Completeness.summary(Completeness.check(tmp_dir, @editions, "2025")) ==
               "Editions 2023, 2024 held"
    end

    test "says there is nothing to hold when the only archived edition is the current one" do
      assert Completeness.summary(Completeness.check(nil, %{"2025" => ["/2025/"]}, "2025")) ==
               "no edition to hold"
    end

    test "joins the problems when there are any", %{tmp_dir: tmp_dir} do
      hold(tmp_dir, ["/2023/", "/2023/course/101-command-line/"])

      assert Completeness.summary(Completeness.check(tmp_dir, @editions, "2025")) ==
               "Edition 2024 is missing 2 pages from #{tmp_dir}: /2024/, /2024/cheatsheets/git/"
    end
  end

  defp hold(dir, paths) do
    Enum.each(paths, fn path ->
      page = Path.join([dir, path, "index.html"])
      File.mkdir_p!(Path.dirname(page))
      File.write!(page, path)
    end)
  end
end
