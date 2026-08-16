defmodule ArchiDep.CourseSite.Archives.MappingTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.Archives.Mapping
  alias ArchiDep.CourseSite.Archives.Overrides
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section

  describe "build/3" do
    test "sends every page of an edition to the page of the course that kept its name" do
      ssh = DocumentRef.new(104, "ssh", :subject)
      git = Cheatsheet.new("git", "Git")

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [
                     {"/", :home},
                     {"/course/104-ssh/", {:chapter, 104, "ssh"}},
                     {"/cheatsheets/git/", {:cheatsheet, "git"}}
                   ]
                 }
               ],
               no_overrides(),
               %Structure{
                 sections: [Section.new(1, "Security", [Chapter.new(ssh, "SSH")])],
                 cheatsheets: [git]
               }
             ) ==
               {:ok,
                %Mapping{
                  entries: %{
                    "/2025/" => :home,
                    "/2025/course/104-ssh/" => {:document, ssh},
                    "/2025/cheatsheets/git/" => {:cheatsheet, "git"}
                  }
                }}
    end

    test "follows a chapter that was renumbered, which needs no override" do
      renumbered = DocumentRef.new(206, "ssh", :subject)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               no_overrides(),
               %Structure{
                 sections: [Section.new(2, "Security", [Chapter.new(renumbered, "SSH")])],
                 cheatsheets: []
               }
             ) == {:ok, %Mapping{entries: %{"/2025/course/104-ssh/" => {:document, renumbered}}}}
    end

    test "follows a chapter that became an exercise, which is the same page at the same address" do
      exercise = DocumentRef.new(104, "ssh", :exercise)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               no_overrides(),
               %Structure{
                 sections: [Section.new(1, "Security", [Chapter.new(exercise, "SSH")])],
                 cheatsheets: []
               }
             ) == {:ok, %Mapping{entries: %{"/2025/course/104-ssh/" => {:document, exercise}}}}
    end

    test "matches a deck against a deck rather than against its chapter" do
      chapter = DocumentRef.new(104, "ssh", :subject)
      deck = DocumentRef.new(104, "ssh", :slides)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [
                     {"/course/104-ssh/", {:chapter, 104, "ssh"}},
                     {"/course/104-ssh/slides/", {:chapter_slides, 104, "ssh"}}
                   ]
                 }
               ],
               no_overrides(),
               %Structure{
                 sections: [
                   Section.new(1, "Security", [Chapter.new(chapter, "SSH", slides: deck)])
                 ],
                 cheatsheets: []
               }
             ) ==
               {:ok,
                %Mapping{
                  entries: %{
                    "/2025/course/104-ssh/" => {:document, chapter},
                    "/2025/course/104-ssh/slides/" => {:document, deck}
                  }
                }}
    end

    test "sends a renamed page where the course says it went" do
      renamed = DocumentRef.new(106, "secure-shell", :subject)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               overrides(%{"2025" => %{"/course/104-ssh/" => "/course/106-secure-shell/"}}),
               %Structure{
                 sections: [Section.new(1, "Security", [Chapter.new(renamed, "Secure Shell")])],
                 cheatsheets: []
               }
             ) == {:ok, %Mapping{entries: %{"/2025/course/104-ssh/" => {:document, renamed}}}}
    end

    test "records a page the course says is gone" do
      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/cheatsheets/unix/", {:cheatsheet, "unix"}}]
                 }
               ],
               overrides(%{"2025" => %{"/cheatsheets/unix/" => :gone}}),
               %Structure{sections: [], cheatsheets: []}
             ) == {:ok, %Mapping{entries: %{"/2025/cheatsheets/unix/" => :gone}}}
    end

    test "prefers what the course declared to what a slug happens to match" do
      kept = DocumentRef.new(104, "ssh", :subject)
      elsewhere = DocumentRef.new(105, "tunnels", :subject)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               overrides(%{"2025" => %{"/course/104-ssh/" => "/course/105-tunnels/"}}),
               %Structure{
                 sections: [
                   Section.new(1, "Security", [
                     Chapter.new(kept, "SSH"),
                     Chapter.new(elsewhere, "Tunnels")
                   ])
                 ],
                 cheatsheets: []
               }
             ) == {:ok, %Mapping{entries: %{"/2025/course/104-ssh/" => {:document, elsewhere}}}}
    end

    test "keeps the editions apart, each with its own declarations" do
      ssh = DocumentRef.new(104, "ssh", :subject)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 },
                 %Manifest{edition: "2026", pages: [{"/course/204-ssh/", {:chapter, 204, "ssh"}}]}
               ],
               overrides(%{"2025" => %{"/course/104-ssh/" => :gone}}),
               %Structure{
                 sections: [Section.new(1, "Security", [Chapter.new(ssh, "SSH")])],
                 cheatsheets: []
               }
             ) ==
               {:ok,
                %Mapping{
                  entries: %{
                    "/2025/course/104-ssh/" => :gone,
                    "/2026/course/204-ssh/" => {:document, ssh}
                  }
                }}
    end

    test "answers for no page when nothing has been archived" do
      assert Mapping.build([], no_overrides(), %Structure{sections: [], cheatsheets: []}) ==
               {:ok, %Mapping{entries: %{}}}
    end

    test "refuses a page the course no longer holds and nothing accounts for" do
      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [
                     {"/course/104-ssh/", {:chapter, 104, "ssh"}},
                     {"/cheatsheets/unix/", {:cheatsheet, "unix"}}
                   ]
                 }
               ],
               no_overrides(),
               %Structure{sections: [], cheatsheets: []}
             ) ==
               {:error,
                [
                  {:unresolved, "2025", "/course/104-ssh/"},
                  {:unresolved, "2025", "/cheatsheets/unix/"}
                ]}
    end

    test "refuses a page whose slug the course now uses twice" do
      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               no_overrides(),
               %Structure{
                 sections: [
                   Section.new(1, "Security", [
                     Chapter.new(DocumentRef.new(104, "ssh", :subject), "SSH")
                   ]),
                   Section.new(2, "Deployment", [
                     Chapter.new(DocumentRef.new(204, "ssh", :exercise), "SSH again")
                   ])
                 ],
                 cheatsheets: []
               }
             ) ==
               {:error, [{:ambiguous, "2025", "/course/104-ssh/", {:chapter, 104, "ssh"}}]}
    end

    test "refuses a declaration sending a page where the course holds nothing" do
      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               overrides(%{"2025" => %{"/course/104-ssh/" => "/course/999-nowhere/"}}),
               %Structure{sections: [], cheatsheets: []}
             ) ==
               {:error,
                [
                  {:unknown_override_target, "2025", "/course/104-ssh/", "/course/999-nowhere/"}
                ]}
    end

    test "refuses a declaration about a page its edition never published" do
      ssh = DocumentRef.new(104, "ssh", :subject)

      assert Mapping.build(
               [
                 %Manifest{
                   edition: "2025",
                   pages: [{"/course/104-ssh/", {:chapter, 104, "ssh"}}]
                 }
               ],
               overrides(%{
                 "2025" => %{"/course/104-shh/" => :gone, "/course/104-hss/" => :gone}
               }),
               %Structure{
                 sections: [Section.new(1, "Security", [Chapter.new(ssh, "SSH")])],
                 cheatsheets: []
               }
             ) ==
               {:error,
                [
                  {:unknown_override_source, "2025", "/course/104-hss/"},
                  {:unknown_override_source, "2025", "/course/104-shh/"}
                ]}
    end

    test "refuses declarations about an edition that is not archived" do
      assert Mapping.build(
               [],
               overrides(%{"2025" => %{"/a/" => :gone}, "2031" => %{"/b/" => :gone}}),
               %Structure{sections: [], cheatsheets: []}
             ) ==
               {:error,
                [{:unknown_override_edition, "2025"}, {:unknown_override_edition, "2031"}]}
    end

    test "refuses one edition archived twice" do
      assert Mapping.build(
               [
                 %Manifest{edition: "2025", pages: []},
                 %Manifest{edition: "2025", pages: []}
               ],
               no_overrides(),
               %Structure{sections: [], cheatsheets: []}
             ) == {:error, [{:duplicate_manifest, "2025"}]}
    end
  end

  describe "fetch/2" do
    test "answers with the page the archived one became" do
      ssh = DocumentRef.new(104, "ssh", :subject)
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => {:document, ssh}}}

      assert Mapping.fetch(mapping, "/2025/course/104-ssh/") == {:ok, {:document, ssh}}
    end

    test "answers with the key that matched for a page declared gone" do
      mapping = %Mapping{entries: %{"/2025/cheatsheets/unix/" => :gone}}

      assert Mapping.fetch(mapping, "/2025/cheatsheets/unix/") ==
               {:gone, "/2025/cheatsheets/unix/"}
    end

    test "answers for no page this application never published" do
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => :home}}

      assert Mapping.fetch(mapping, "/2025/course/999-nope/") == :error
    end

    test "answers for nothing off-site, which can match no key" do
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => :home}}

      assert Mapping.fetch(mapping, "https://evil.example/2025/course/104-ssh/") == :error
    end

    test "answers for nothing climbing out of an edition, which can match no key" do
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => :home}}

      assert Mapping.fetch(mapping, "/2025/../../etc/passwd") == :error
    end

    test "answers for a value that is not even a string" do
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => :home}}

      assert Mapping.fetch(mapping, ["/2025/course/104-ssh/"]) == :error
    end

    test "answers for a value that is missing altogether" do
      mapping = %Mapping{entries: %{"/2025/course/104-ssh/" => :home}}

      assert Mapping.fetch(mapping, nil) == :error
    end
  end

  describe "entries/1" do
    test "hands back the whole mapping as data" do
      entries = %{"/2025/" => :home, "/2025/cheatsheets/unix/" => :gone}

      assert Mapping.entries(%Mapping{entries: entries}) == entries
    end
  end

  describe "format_error/1" do
    test "describes one edition archived twice" do
      assert Mapping.format_error({:duplicate_manifest, "2025"}) ==
               "Edition 2025 is archived twice"
    end

    test "describes a page nothing accounts for" do
      assert Mapping.format_error({:unresolved, "2025", "/course/104-ssh/"}) ==
               ~s|Edition 2025 published "/course/104-ssh/", which the course no longer holds; say where it went in course/archives.yml, or declare it gone|
    end

    test "describes a page whose slug the course now uses twice" do
      assert Mapping.format_error(
               {:ambiguous, "2025", "/course/104-ssh/", {:chapter, 104, "ssh"}}
             ) ==
               ~s|Edition 2025 published "/course/104-ssh/", and the course now holds more than one "ssh" chapter; say which one it is in course/archives.yml|
    end

    test "describes an ambiguous deck" do
      assert Mapping.format_error(
               {:ambiguous, "2025", "/course/104-ssh/slides/", {:chapter_slides, 104, "ssh"}}
             ) ==
               ~s|Edition 2025 published "/course/104-ssh/slides/", and the course now holds more than one "ssh" slide deck; say which one it is in course/archives.yml|
    end

    test "describes an ambiguous cheatsheet" do
      assert Mapping.format_error({:ambiguous, "2025", "/cheatsheets/git/", {:cheatsheet, "git"}}) ==
               ~s|Edition 2025 published "/cheatsheets/git/", and the course now holds more than one "git" cheatsheet; say which one it is in course/archives.yml|
    end

    test "describes an ambiguous home page" do
      assert Mapping.format_error({:ambiguous, "2025", "/", :home}) ==
               ~s|Edition 2025 published "/", and the course now holds more than one home page; say which one it is in course/archives.yml|
    end

    test "describes declarations about an edition that is not archived" do
      assert Mapping.format_error({:unknown_override_edition, "2031"}) ==
               "course/archives.yml declares edition 2031, which is not archived"
    end

    test "describes a declaration about a page its edition never published" do
      assert Mapping.format_error({:unknown_override_source, "2025", "/course/104-shh/"}) ==
               ~s|course/archives.yml sends "/course/104-shh/", which edition 2025 never published|
    end

    test "describes a declaration sending a page where the course holds nothing" do
      assert Mapping.format_error(
               {:unknown_override_target, "2025", "/course/104-ssh/", "/course/999-nowhere/"}
             ) ==
               ~s|course/archives.yml sends edition 2025's "/course/104-ssh/" to "/course/999-nowhere/", which the course does not hold|
    end
  end

  defp no_overrides, do: %Overrides{editions: %{}}

  defp overrides(editions),
    do: %Overrides{
      editions:
        Map.new(editions, fn {edition, entries} ->
          {edition, Map.new(entries, fn {source, target} -> {source, target(target)} end)}
        end)
    }

  defp target(:gone), do: :gone
  defp target(path) when is_binary(path), do: {:page, path}
end
