defmodule ArchiDep.CourseSite.Structure.ChapterTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Structure.Chapter

  doctest ArchiDep.CourseSite.Structure.Chapter

  describe "new/3" do
    test "builds a chapter that is a subject with a deck beside it" do
      subject = DocumentRef.new(408, "unix-networking", :subject)
      slides = DocumentRef.new(408, "unix-networking", :slides)

      assert Chapter.new(subject, "Unix Networking", slides: slides) ==
               %Chapter{
                 page: subject,
                 title: "Unix Networking",
                 slides: slides,
                 graded?: false
               }
    end

    test "builds a chapter that is a graded exercise" do
      exercise = DocumentRef.new(603, "floodit-deployment", :exercise)

      assert Chapter.new(exercise, "Deploy Flood It", graded?: true) ==
               %Chapter{
                 page: exercise,
                 title: "Deploy Flood It",
                 slides: nil,
                 graded?: true
               }
    end

    test "builds a chapter that is a deck of its own" do
      slides = DocumentRef.new(513, "tls", :slides)

      assert Chapter.new(slides, "TLS/SSL Certificates") ==
               %Chapter{page: slides, title: "TLS/SSL Certificates", slides: nil, graded?: false}
    end
  end

  describe "section_chapter/1" do
    test "is the position of a chapter within its section" do
      chapters =
        Enum.map(
          [104, 110, 201, 899],
          &Chapter.new(DocumentRef.new(&1, "chapter-#{&1}", :subject), "Chapter #{&1}")
        )

      assert Enum.map(chapters, &{Chapter.section(&1), Chapter.section_chapter(&1)}) ==
               [{1, 4}, {1, 10}, {2, 1}, {8, 99}]
    end
  end
end
