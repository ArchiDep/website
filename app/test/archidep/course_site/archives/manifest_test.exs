defmodule ArchiDep.CourseSite.Archives.ManifestTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.Archives.Manifest
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.Support.CourseSiteFactory

  doctest ArchiDep.CourseSite.Archives.Manifest

  describe "of/2" do
    test "records the home page, every chapter, the decks and the cheatsheets, in reading order" do
      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line",
              slides: DocumentRef.new(101, "command-line", :slides)
            ),
            Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell")
          ]),
          Section.new(2, "Security", [
            Chapter.new(DocumentRef.new(201, "ssh", :subject), "SSH")
          ])
        ],
        cheatsheets: [Cheatsheet.new("git", "Git"), Cheatsheet.new("sysadmin", "Sysadmin")]
      }

      assert Manifest.of("2025", structure) == %Manifest{
               edition: "2025",
               pages: [
                 {"/", :home},
                 {"/course/101-command-line/", {:chapter, 101, "command-line"}},
                 {"/course/101-command-line/slides/", {:chapter_slides, 101, "command-line"}},
                 {"/course/102-hello-shell/", {:chapter, 102, "hello-shell"}},
                 {"/course/201-ssh/", {:chapter, 201, "ssh"}},
                 {"/cheatsheets/git/", {:cheatsheet, "git"}},
                 {"/cheatsheets/sysadmin/", {:cheatsheet, "sysadmin"}}
               ]
             }
    end

    test "records a course of nothing but its home page" do
      assert Manifest.of("2031", %Structure{sections: [], cheatsheets: []}) == %Manifest{
               edition: "2031",
               pages: [{"/", :home}]
             }
    end
  end

  describe "to_json/1" do
    test "writes the version, the edition and every page, in that order" do
      manifest = %Manifest{
        edition: "2025",
        pages: [
          {"/", :home},
          {"/course/507-dns/", {:chapter, 507, "dns"}},
          {"/course/507-dns/slides/", {:chapter_slides, 507, "dns"}},
          {"/cheatsheets/git/", {:cheatsheet, "git"}}
        ]
      }

      assert Manifest.to_json(manifest) == """
             {
               "version": 1,
               "edition": "2025",
               "pages": [
                 {
                   "path": "/",
                   "kind": "home"
                 },
                 {
                   "path": "/course/507-dns/",
                   "kind": "chapter",
                   "num": 507,
                   "slug": "dns"
                 },
                 {
                   "path": "/course/507-dns/slides/",
                   "kind": "chapter_slides",
                   "num": 507,
                   "slug": "dns"
                 },
                 {
                   "path": "/cheatsheets/git/",
                   "kind": "cheatsheet",
                   "slug": "git"
                 }
               ]
             }
             """
    end
  end

  describe "from_json/1" do
    test "reads every kind of page a manifest may hold" do
      assert Manifest.from_json(%{
               "version" => 1,
               "edition" => "2025",
               "pages" => [
                 %{"path" => "/", "kind" => "home"},
                 %{
                   "path" => "/course/104-ssh/",
                   "kind" => "chapter",
                   "num" => 104,
                   "slug" => "ssh"
                 },
                 %{
                   "path" => "/course/104-ssh/slides/",
                   "kind" => "chapter_slides",
                   "num" => 104,
                   "slug" => "ssh"
                 },
                 %{"path" => "/cheatsheets/docker/", "kind" => "cheatsheet", "slug" => "docker"}
               ]
             }) ==
               {:ok,
                %Manifest{
                  edition: "2025",
                  pages: [
                    {"/", :home},
                    {"/course/104-ssh/", {:chapter, 104, "ssh"}},
                    {"/course/104-ssh/slides/", {:chapter_slides, 104, "ssh"}},
                    {"/cheatsheets/docker/", {:cheatsheet, "docker"}}
                  ]
                }}
    end

    test "reads an edition that published nothing" do
      assert Manifest.from_json(%{"version" => 1, "edition" => "1955", "pages" => []}) ==
               {:ok, %Manifest{edition: "1955", pages: []}}
    end

    test "refuses a manifest of another version" do
      assert Manifest.from_json(%{"version" => 9, "edition" => "2025", "pages" => []}) ==
               {:error, {:unsupported_manifest_version, 9}}
    end

    test "refuses a manifest with no version" do
      assert Manifest.from_json(%{"edition" => "2025", "pages" => []}) ==
               {:error, {:malformed_manifest, ~s{no "version"}}}
    end

    test "refuses a manifest that is not a map" do
      assert Manifest.from_json(["2025"]) ==
               {:error, {:malformed_manifest, ~s{["2025"] is not a map}}}
    end

    test "refuses a manifest with no edition" do
      assert Manifest.from_json(%{"version" => 1, "pages" => []}) ==
               {:error, {:malformed_manifest, ~s{no "edition"}}}
    end

    test "refuses a manifest whose edition is not one" do
      assert Manifest.from_json(%{"version" => 1, "edition" => 2025, "pages" => []}) ==
               {:error, {:malformed_manifest, "2025 is not an edition"}}
    end

    test "refuses a manifest with no pages" do
      assert Manifest.from_json(%{"version" => 1, "edition" => "2025"}) ==
               {:error, {:malformed_manifest, ~s{no "pages" list}}}
    end

    test "refuses a manifest whose pages are not a list" do
      assert Manifest.from_json(%{"version" => 1, "edition" => "2025", "pages" => %{}}) ==
               {:error, {:malformed_manifest, ~s{"pages" is not a list}}}
    end

    test "refuses a page published at no path" do
      assert Manifest.from_json(%{
               "version" => 1,
               "edition" => "2025",
               "pages" => [%{"kind" => "home"}]
             }) ==
               {:error, {:malformed_manifest, ~s|%{"kind" => "home"} is published at no path|}}
    end

    test "refuses a page identified as nothing this application understands" do
      assert Manifest.from_json(%{
               "version" => 1,
               "edition" => "2025",
               "pages" => [%{"path" => "/notes/", "kind" => "note", "slug" => "x"}]
             }) ==
               {:error,
                {:malformed_manifest,
                 ~s|"/notes/" is identified as %{"kind" => "note", "slug" => "x"}|}}
    end

    test "refuses a chapter whose number is not one" do
      assert Manifest.from_json(%{
               "version" => 1,
               "edition" => "2025",
               "pages" => [
                 %{
                   "path" => "/course/x-ssh/",
                   "kind" => "chapter",
                   "num" => "104",
                   "slug" => "ssh"
                 }
               ]
             }) ==
               {:error,
                {:malformed_manifest,
                 ~s|"/course/x-ssh/" is identified as %{"kind" => "chapter", "num" => "104", "slug" => "ssh"}|}}
    end

    test "refuses a manifest publishing one path twice" do
      assert Manifest.from_json(%{
               "version" => 1,
               "edition" => "2025",
               "pages" => [
                 %{
                   "path" => "/course/104-ssh/",
                   "kind" => "chapter",
                   "num" => 104,
                   "slug" => "ssh"
                 },
                 %{
                   "path" => "/course/104-ssh/",
                   "kind" => "chapter",
                   "num" => 104,
                   "slug" => "secure-shell"
                 }
               ]
             }) == {:error, {:duplicate_page, "/course/104-ssh/"}}
    end

    property "reads back every manifest it writes" do
      check all {tree, front_matter, declarations} <- CourseSiteFactory.course_generator() do
        {:ok, structure} = Structure.plan(tree, front_matter, declarations)
        manifest = Manifest.of("2025", structure)

        assert manifest |> Manifest.to_json() |> JSON.decode!() |> Manifest.from_json() ==
                 {:ok, manifest}
      end
    end
  end

  describe "format_error/1" do
    test "describes a manifest of an unsupported version" do
      assert Manifest.format_error({:unsupported_manifest_version, 9}) ==
               "Archive manifest version 9 is not version 1, the one this application reads"
    end

    test "describes a malformed manifest" do
      assert Manifest.format_error({:malformed_manifest, ~s{no "edition"}}) ==
               ~s{Archive manifest is malformed: no "edition"}
    end

    test "describes a manifest publishing one path twice" do
      assert Manifest.format_error({:duplicate_page, "/cheatsheets/git/"}) ==
               ~s{Archive manifest lists "/cheatsheets/git/" twice}
    end
  end
end
