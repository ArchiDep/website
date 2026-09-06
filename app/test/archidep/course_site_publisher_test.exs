defmodule ArchiDep.CourseSitePublisherTest do
  # `put_course_site_config/1` replaces application environment, which is global
  # to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers, only: [put_course_site_config: 1]
  import ExUnit.CaptureLog

  alias ArchiDep.CourseSite.Build.Site
  alias ArchiDep.CourseSite.Builder.Report
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSitePublisher
  alias ArchiDep.Git

  @moduletag :tmp_dir

  describe "options/1" do
    test "is the self-contained build a static server can be pointed at", %{tmp_dir: tmp_dir} do
      put_course_site_config(
        build_id: "boot",
        years: "2031-2032",
        years_short: "31-32",
        pdf_base: {:external, "https://example.com/pdf/2031"},
        version: "2031"
      )

      assert CourseSitePublisher.options(
               course_dir: Path.join(tmp_dir, "course"),
               build_dir: Path.join(tmp_dir, "build")
             ) == [
               content_dir: Path.join(tmp_dir, "course"),
               home_file: Path.join(tmp_dir, "course/index.md"),
               includes_dir: Path.join(tmp_dir, "course"),
               declarations_file: Path.join(tmp_dir, "course/course.yml"),
               root_files_dir: Path.join(tmp_dir, "course"),
               static_dir: Application.app_dir(:archidep, "priv/static"),
               digested: true,
               carry_assets: true,
               pdf_base: {:external, "https://example.com/pdf/2031"},
               output_dir: Path.join(tmp_dir, "build"),
               output: :swap,
               options: CourseSitePublisher.build_options()
             ]
    end

    test "is what the caller says it is when the caller says", %{tmp_dir: tmp_dir} do
      options =
        Site.Options.new(
          urls:
            UrlContext.new(
              mode: :archive,
              version: "2031",
              build_id: "stated",
              live_site_url: "https://archidep.ch"
            ),
          site:
            SiteInfo.new(
              version: "9.8.7",
              git_branch: "archive/2031",
              git_revision: "beefbee",
              years: "2031-2032",
              years_short: "31-32"
            )
        )

      assert CourseSitePublisher.options(
               course_dir: Path.join(tmp_dir, "course"),
               build_dir: Path.join(tmp_dir, "build"),
               static_dir: Path.join(tmp_dir, "static"),
               digested: false,
               carry_assets: false,
               pdf_base: nil,
               options: options
             ) == [
               content_dir: Path.join(tmp_dir, "course"),
               home_file: Path.join(tmp_dir, "course/index.md"),
               includes_dir: Path.join(tmp_dir, "course"),
               declarations_file: Path.join(tmp_dir, "course/course.yml"),
               root_files_dir: Path.join(tmp_dir, "course"),
               static_dir: Path.join(tmp_dir, "static"),
               digested: false,
               carry_assets: false,
               pdf_base: nil,
               output_dir: Path.join(tmp_dir, "build"),
               output: :swap,
               options: options
             ]
    end
  end

  describe "build_options/0" do
    test "says what this deployment's build is" do
      put_course_site_config(
        # `:live` because that is the only mode this can produce: the modes that
        # render a copy of the site have to say where the current edition is,
        # and nothing reads that from configuration — a build of one is asked
        # for at the command line.
        mode: :live,
        base_path: "/archived",
        version: "2019",
        build_id: "1a2b3c4d",
        years: "2019-2020",
        years_short: "19-20"
      )

      assert CourseSitePublisher.build_options() ==
               Site.Options.new(
                 urls:
                   UrlContext.new(
                     mode: :live,
                     base_path: "/archived",
                     version: "2019",
                     build_id: "1a2b3c4d"
                   ),
                 site:
                   SiteInfo.new(
                     # The three the checkout answers rather than the
                     # configuration.
                     version: to_string(Application.spec(:archidep, :vsn)),
                     git_branch: Git.git_branch(),
                     git_revision: Git.git_revision(),
                     years: "2019-2020",
                     years_short: "19-20"
                   )
               )
    end
  end

  describe "publish/2" do
    test "hands the builder how far the course has got, and the build", %{tmp_dir: tmp_dir} do
      test = self()
      sessions = [Session.new(~D[2031-03-03], "Deployment", [801], [802], [])]

      report = %Report{
        output_dir: Path.join(tmp_dir, "build"),
        pages: 12,
        chapters: 9,
        files: 34,
        page_assets: 56,
        assets: 78
      }

      build_opts = [output_dir: Path.join(tmp_dir, "build"), options: :whatever]

      capture_log(fn ->
        assert CourseSitePublisher.publish(build_opts,
                 progress: fn -> sessions end,
                 builder: fn opts ->
                   send(test, {:built, opts})
                   {:ok, report}
                 end
               ) == {:ok, report}
      end)

      assert_received {:built, opts}

      assert opts == [
               progress: sessions,
               output_dir: Path.join(tmp_dir, "build"),
               options: :whatever
             ]
    end

    test "says what was wrong with a build that failed" do
      failure = {:error, "The site could not be rendered", ["a document says nothing"]}

      capture_log(fn ->
        assert CourseSitePublisher.publish([],
                 progress: fn -> [] end,
                 builder: fn _opts -> failure end
               ) == failure
      end)
    end
  end
end
