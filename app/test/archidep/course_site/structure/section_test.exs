defmodule ArchiDep.CourseSite.Structure.SectionTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section

  doctest ArchiDep.CourseSite.Structure.Section

  describe "new/3" do
    test "builds a section holding the chapters numbered for it" do
      chapter =
        Chapter.new(DocumentRef.new(301, "security", :subject), "Security")

      assert Section.new(3, "Security", [chapter]) ==
               %Section{index: 3, title: "Security", chapters: [chapter]}
    end

    test "builds a section that is still to be written" do
      assert Section.new(6, "Automated Deployment") ==
               %Section{index: 6, title: "Automated Deployment", chapters: []}
    end
  end

  describe "slug/1" do
    test "names a section after its title, as a course URL would" do
      titles = [
        "Introduction",
        "Version Control",
        "Docker Deployment",
        "TLS/SSL & Certificates",
        "Le déploiement"
      ]

      sections = Enum.map(Enum.with_index(titles, 1), fn {title, i} -> Section.new(i, title) end)

      assert Enum.map(sections, &Section.slug/1) == [
               "introduction",
               "version-control",
               "docker-deployment",
               "tlsssl--certificates",
               "le-dploiement"
             ]
    end
  end
end
