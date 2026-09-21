defmodule ArchiDepWeb.Admin.Classes.StudentFiltersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.StudentView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.Classes.StudentFilters

  defp student(academic_class, registered?),
    do:
      StudentView.from(
        CourseFactory.build(:student,
          academic_class: academic_class,
          user: if(registered?, do: CourseFactory.build(:user), else: nil)
        )
      )

  defp filters(academic_class, registered),
    do: %StudentFilters{academic_class: academic_class, registered: registered}

  describe "from_params/1" do
    test "parse no filters from empty parameters" do
      assert StudentFilters.from_params(%{}) == filters(nil, nil)
    end

    test "parse no filters from blank values" do
      assert StudentFilters.from_params(%{"academic_class" => "", "registered" => ""}) ==
               filters(nil, nil)
    end

    test "parse an academic class and a registration state" do
      assert StudentFilters.from_params(%{"academic_class" => "INF-1", "registered" => "yes"}) ==
               filters("INF-1", true)

      assert StudentFilters.from_params(%{"academic_class" => "INF-2", "registered" => "no"}) ==
               filters("INF-2", false)
    end

    test "parse the absence of an academic class" do
      assert StudentFilters.from_params(%{"academic_class" => " "}) == filters(:none, nil)
    end

    test "ignore unknown parameters and values" do
      assert StudentFilters.from_params(%{
               "_target" => ["registered"],
               "academic_class" => ["INF-1"],
               "registered" => "maybe"
             }) == filters(nil, nil)
    end
  end

  describe "to_params/1" do
    test "omit inactive filters" do
      assert StudentFilters.to_params(StudentFilters.none()) == %{}
    end

    test "serialize every active filter" do
      assert StudentFilters.to_params(filters("INF-1", true)) == %{
               "academic_class" => "INF-1",
               "registered" => "yes"
             }

      assert StudentFilters.to_params(filters(:none, false)) == %{
               "academic_class" => " ",
               "registered" => "no"
             }
    end

    test "round-trip through from_params/1" do
      for academic_class <- [nil, :none, "INF-1"], registered <- [nil, true, false] do
        original = filters(academic_class, registered)

        assert original |> StudentFilters.to_params() |> StudentFilters.from_params() ==
                 original
      end
    end
  end

  describe "active?/1" do
    test "be inactive without any filter" do
      assert StudentFilters.active?(StudentFilters.none()) == false
    end

    test "be active with any filter" do
      assert StudentFilters.active?(filters("INF-1", nil)) == true
      assert StudentFilters.active?(filters(:none, nil)) == true
      assert StudentFilters.active?(filters(nil, false)) == true
      assert StudentFilters.active?(filters(nil, true)) == true
    end
  end

  describe "filter/2" do
    setup do
      students = %{
        inf1_registered: student("INF-1", true),
        inf1_unregistered: student("INF-1", false),
        inf2_unregistered: student("INF-2", false),
        none_registered: student(nil, true)
      }

      all = [
        students.inf1_registered,
        students.inf1_unregistered,
        students.inf2_unregistered,
        students.none_registered
      ]

      %{s: students, all: all}
    end

    test "keep every student without any filter", %{all: all} do
      assert StudentFilters.filter(StudentFilters.none(), all) == all
    end

    test "keep the students of an academic class", %{s: s, all: all} do
      assert StudentFilters.filter(filters("INF-1", nil), all) == [
               s.inf1_registered,
               s.inf1_unregistered
             ]
    end

    test "keep the students without an academic class", %{s: s, all: all} do
      assert StudentFilters.filter(filters(:none, nil), all) == [s.none_registered]
    end

    test "keep the students by registration state", %{s: s, all: all} do
      assert StudentFilters.filter(filters(nil, true), all) == [
               s.inf1_registered,
               s.none_registered
             ]

      assert StudentFilters.filter(filters(nil, false), all) == [
               s.inf1_unregistered,
               s.inf2_unregistered
             ]
    end

    test "combine the filters", %{s: s, all: all} do
      assert StudentFilters.filter(filters("INF-1", false), all) == [s.inf1_unregistered]
      assert StudentFilters.filter(filters("INF-2", true), all) == []
    end
  end

  describe "academic_class_options/2" do
    test "list no options without students" do
      assert StudentFilters.academic_class_options(StudentFilters.none(), []) == []
    end

    test "list each academic class once, sorted, with the absence of one last" do
      students = [
        student("INF-2", false),
        student(nil, false),
        student("INF-1", true),
        student("INF-2", true)
      ]

      assert StudentFilters.academic_class_options(StudentFilters.none(), students) == [
               "INF-1",
               "INF-2",
               :none
             ]
    end

    test "include the filtered academic class even if no student has it" do
      students = [student("INF-1", false)]

      assert StudentFilters.academic_class_options(filters("INF-9", nil), students) == [
               "INF-1",
               "INF-9"
             ]

      assert StudentFilters.academic_class_options(filters(:none, nil), students) == [
               "INF-1",
               :none
             ]
    end
  end
end
