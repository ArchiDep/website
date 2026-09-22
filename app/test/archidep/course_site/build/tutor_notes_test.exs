defmodule ArchiDep.CourseSite.Build.TutorNotesTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.TutorNotes
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry

  doctest TutorNotes

  describe "text/5" do
    test "adds the troubleshooting entries of an exercise, linked on the main site" do
      page = {:document, DocumentRef.new(506, "systemd-deployment", :exercise)}

      content = %Page{
        html: "",
        excerpt_html: nil,
        toc: [
          %Entry{id: "deploy", level: 2, label_html: "Deploy"},
          %Entry{
            id: "troubleshooting",
            level: 2,
            label_html: ~s{<img class="emoji" src="/e/1f4a5.svg" alt="💥" /> Troubleshooting},
            entries: [
              %Entry{
                id: "my-service-is-not-running",
                level: 3,
                label_html:
                  ~s{<img class="emoji" src="/e/1f4a5.svg" alt="💥" /> My service is not running}
              },
              %Entry{
                id: "codeexited-status200chdir",
                level: 3,
                label_html:
                  ~s{<img class="emoji" src="/e/1f4a5.svg" alt="💥" /> <code>code=exited, status=200/CHDIR</code> &amp; <em>more</em>},
                entries: [%Entry{id: "on-debian", level: 4, label_html: "On Debian"}]
              }
            ]
          },
          %Entry{id: "what-have-i-done", level: 2, label_html: "What have I done?"}
        ]
      }

      urls = build(:url_context, mode: :live, base_path: "/site", version: "2026")

      assert TutorNotes.text(
               "# Tutor notes: 506 systemd\n\n## Common pitfalls\n\n- One.\n\n",
               page,
               content,
               urls,
               "https://archidep.example.com"
             ) ==
               {:ok,
                """
                # Tutor notes: 506 systemd

                ## Common pitfalls

                - One.

                ## Troubleshooting on the page

                The page's "Troubleshooting" section: https://archidep.example.com/site/2026/course/506-systemd-deployment/#troubleshooting

                Its entries, with their anchors on that page:

                - My service is not running (#my-service-is-not-running)
                - `code=exited, status=200/CHDIR` & more (#codeexited-status200chdir)
                """}
    end

    test "links a troubleshooting section with no headings under it as a whole" do
      page = {:document, DocumentRef.new(409, "tcp", :exercise)}

      content = %Page{
        html: "",
        excerpt_html: nil,
        toc: [%Entry{id: "troubleshooting", level: 2, label_html: "Troubleshooting"}]
      }

      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text("# Tutor notes: 409 TCP\n", page, content, urls, "https://a.example") ==
               {:ok,
                """
                # Tutor notes: 409 TCP

                ## Troubleshooting on the page

                The page's "Troubleshooting" section: https://a.example/course/409-tcp/#troubleshooting
                """}
    end

    test "finds a troubleshooting section under a heading of the page" do
      page = {:document, DocumentRef.new(410, "sftp-deployment", :exercise)}

      content = %Page{
        html: "",
        excerpt_html: nil,
        toc: [
          %Entry{
            id: "sftp",
            level: 1,
            label_html: "SFTP",
            entries: [
              %Entry{
                id: "troubleshooting",
                level: 2,
                label_html: "Troubleshooting",
                entries: [%Entry{id: "denied", level: 3, label_html: "Denied"}]
              }
            ]
          }
        ]
      }

      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text("# Notes of 410\n", page, content, urls, "https://b.example") ==
               {:ok,
                """
                # Notes of 410

                ## Troubleshooting on the page

                The page's "Troubleshooting" section: https://b.example/course/410-sftp-deployment/#troubleshooting

                Its entries, with their anchors on that page:

                - Denied (#denied)
                """}
    end

    test "says that an exercise has no troubleshooting section" do
      page = {:document, DocumentRef.new(104, "hello-ssh", :exercise)}

      content = %Page{
        html: "",
        excerpt_html: nil,
        toc: [%Entry{id: "connect", level: 2, label_html: "Connect"}]
      }

      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text("# Notes of 104", page, content, urls, "https://c.example") ==
               {:ok,
                """
                # Notes of 104

                ## Troubleshooting on the page

                The page has no "Troubleshooting" section.
                """}
    end

    test "adds nothing to the notes of a subject without a troubleshooting section" do
      page = {:document, DocumentRef.new(103, "ssh", :subject)}

      content = %Page{
        html: "",
        excerpt_html: nil,
        toc: [%Entry{id: "keys", level: 2, label_html: "Keys"}]
      }

      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text("# Notes of 103\n\n", page, content, urls, "https://d.example") ==
               {:ok, "# Notes of 103\n\n"}
    end

    test "adds nothing to the notes of a chapter whose page is a deck" do
      page = {:document, DocumentRef.new(202, "git-branching", :slides)}
      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text(
               "# Notes of 202\n",
               page,
               %Slides{markdown: "# Branching\n"},
               urls,
               "https://e.example"
             ) == {:ok, "# Notes of 202\n"}
    end

    test "refuses notes writing the heading it adds" do
      page = {:document, DocumentRef.new(506, "systemd-deployment", :exercise)}
      content = %Page{html: "", excerpt_html: nil, toc: []}
      urls = build(:url_context, mode: :live, base_path: "", version: nil)

      assert TutorNotes.text(
               "# Notes\n\n## Troubleshooting on the page \n\n- Written by hand.\n",
               page,
               content,
               urls,
               "https://f.example"
             ) == {:error, {:reserved_tutor_notes_heading, "## Troubleshooting on the page"}}
    end
  end

  describe "published_path/2" do
    test "names the notes after what is published of them" do
      assert TutorNotes.published_path("/course/506-systemd-deployment/tutor.md", "# Notes\n") ==
               "/course/506-systemd-deployment/tutor-#{md5("# Notes\n")}.md"
    end
  end

  describe "file_name/1" do
    test "names the notes after what is published of them" do
      assert TutorNotes.file_name("# Other notes\n") == "tutor-#{md5("# Other notes\n")}.md"
    end
  end

  describe "format_error/1" do
    test "describes notes writing the heading the build adds" do
      assert TutorNotes.format_error(
               {:reserved_tutor_notes_heading, "## Troubleshooting on the page"}
             ) ==
               ~s{Tutor notes must not write the heading "## Troubleshooting on the page", which the build adds}
    end
  end

  defp md5(text), do: :md5 |> :crypto.hash(text) |> Base.encode16(case: :lower)
end
