defmodule ArchiDep.CourseSite.ProgressTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section

  describe "new/1" do
    test "unites what the sessions recorded, later categories subtracted" do
      sessions = [
        build(:session, next: [100, 101, 102, 103]),
        build(:session, done: [100, 101], due: [102], next: [103, 104]),
        build(:session, done: [102], due: [103, 104], next: [105])
      ]

      assert Progress.new(sessions) == %Progress{
               done: MapSet.new([100, 101, 102]),
               due: MapSet.new([103, 104]),
               next: MapSet.new([105])
             }
    end

    test "reads a session that recorded only some of the three categories" do
      assert Progress.new([build(:session, done: [201]), build(:session, next: [202])]) ==
               %Progress{
                 done: MapSet.new([201]),
                 due: MapSet.new([]),
                 next: MapSet.new([202])
               }
    end

    test "reads a course that has been taught no session" do
      assert Progress.new([]) == %Progress{
               done: MapSet.new([]),
               due: MapSet.new([]),
               next: MapSet.new([])
             }
    end
  end

  describe "status/2" do
    test "answers for a section and a chapter out of the same lists" do
      progress = Progress.new([build(:session, done: [300, 301], due: [302], next: [400, 401])])

      assert {
               Progress.status(progress, 300),
               Progress.status(progress, 301),
               Progress.status(progress, 302),
               Progress.status(progress, 400),
               Progress.status(progress, 401),
               Progress.status(progress, 500)
             } == {:done, :done, :due, :next, :next, :future}
    end
  end

  describe "statuses/2" do
    test "answers for every section and every chapter of the course" do
      structure = %Structure{
        sections: [
          Section.new(1, "Introduction", [
            Chapter.new(DocumentRef.new(101, "command-line", :subject), "Command Line"),
            Chapter.new(DocumentRef.new(102, "hello-shell", :exercise), "Hello Shell")
          ]),
          Section.new(2, "Version Control", [
            Chapter.new(DocumentRef.new(201, "git", :subject), "Git")
          ])
        ],
        cheatsheets: []
      }

      progress = Progress.new([build(:session, done: [100, 101], due: [102], next: [200])])

      assert Progress.statuses(progress, structure) == %{
               100 => :done,
               101 => :done,
               102 => :due,
               200 => :next,
               201 => :future
             }
    end
  end

  describe "solutions_revealed?/2" do
    test "shows the answers of a chapter the course has covered and of no other" do
      progress = Progress.new([build(:session, done: [101], due: [102], next: [103])])

      assert {
               Progress.solutions_revealed?(progress, 101),
               Progress.solutions_revealed?(progress, 102),
               Progress.solutions_revealed?(progress, 103),
               Progress.solutions_revealed?(progress, 104)
             } == {true, false, false, false}
    end
  end

  describe "solutions/2" do
    test "withholds the answers of every page but a chapter the course has covered" do
      progress = Progress.new([build(:session, done: [101], due: [102], next: [103])])

      assert {
               Progress.solutions(progress, {:document, DocumentRef.new(101, "cli", :exercise)}),
               Progress.solutions(
                 progress,
                 {:document, DocumentRef.new(102, "shell", :exercise)}
               ),
               Progress.solutions(progress, {:document, DocumentRef.new(103, "ssh", :exercise)}),
               Progress.solutions(progress, {:document, DocumentRef.new(104, "git", :exercise)}),
               Progress.solutions(progress, {:cheatsheet, "sysadmin"}),
               Progress.solutions(progress, :home)
             } == {:revealed, :hidden, :hidden, :hidden, :revealed, :revealed}
    end
  end

  describe "section_open?/2" do
    test "unfolds the section the coming session covers" do
      section =
        Section.new(3, "Security", [
          Chapter.new(DocumentRef.new(301, "security", :subject), "Security")
        ])

      assert Progress.section_open?(%{300 => :next, 301 => :future}, section)
    end

    test "unfolds a section holding a chapter that is due" do
      section =
        Section.new(4, "Basic Deployment", [
          Chapter.new(DocumentRef.new(401, "cloud", :subject), "Cloud"),
          Chapter.new(DocumentRef.new(402, "run-virtual-server", :exercise), "Run a Server")
        ])

      assert Progress.section_open?(%{400 => :done, 401 => :done, 402 => :due}, section)
    end

    test "unfolds a section holding a chapter the coming session covers" do
      section =
        Section.new(5, "Advanced Deployment", [
          Chapter.new(DocumentRef.new(501, "dns", :subject), "DNS")
        ])

      assert Progress.section_open?(%{500 => :done, 501 => :next}, section)
    end

    test "folds a section whose chapters have all been done" do
      section =
        Section.new(6, "Automated Deployment", [
          Chapter.new(DocumentRef.new(601, "git-hooks", :subject), "Git Hooks")
        ])

      refute Progress.section_open?(%{600 => :done, 601 => :done}, section)
    end

    test "folds a section whose chapters are all still to come" do
      section =
        Section.new(7, "Managed Deployment", [
          Chapter.new(DocumentRef.new(701, "paas", :subject), "Platform as a Service")
        ])

      refute Progress.section_open?(%{700 => :future, 701 => :future}, section)
    end

    test "folds a section nothing has been recorded against at all" do
      section =
        Section.new(8, "Docker Deployment", [
          Chapter.new(DocumentRef.new(801, "docker", :subject), "Docker")
        ])

      refute Progress.section_open?(%{}, section)
    end

    test "folds a section that has been done while a later one is due" do
      section =
        Section.new(9, "Quantum Deployment", [
          Chapter.new(DocumentRef.new(901, "qubits", :subject), "Qubits")
        ])

      refute Progress.section_open?(%{900 => :done, 901 => :done, 1001 => :due}, section)
    end
  end
end
