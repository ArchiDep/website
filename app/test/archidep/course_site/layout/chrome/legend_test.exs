defmodule ArchiDep.CourseSite.Layout.Chrome.LegendTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Legend

  # The legend is what explains the pictures, so what a test of it needs is to
  # tell one from another rather than to draw any of them.
  @emoji Map.new(
           ~w(trophy scroll exclamation question space_invader checkered_flag
              classical_building boom),
           &{&1, "<E:#{&1}>"}
         )

  describe "legend/1" do
    test "says an exercise is graded before explaining anything else" do
      assert legend(graded?: true) == expected(graded: graded_markup())
    end

    test "says nothing about grades for an exercise that carries none" do
      assert legend(graded?: false) == expected(graded: "")
    end
  end

  defp legend(graded?: graded?),
    do: render(&Legend.legend/1, %{graded?: graded?, emoji: @emoji})

  defp expected(parts) do
    String.trim_trailing("""
    #{Keyword.fetch!(parts, :graded)}

    <h2 id="legend">
      <E:scroll> Legend
    </h2>

    <p>Parts of this exercise are annotated with the following icons:</p>

    <ul class="legend">
      <li>
        <E:exclamation> A task you MUST perform to complete the exercise
      </li>
      <li>
        <E:question> Optional step that you may perform to make sure that
        everything is working correctly, or to set up additional tools that are not required but can
        help you
      </li>
      <li>
        <E:space_invader> Advanced tips on how to go further (or
        challenges!)
      </li>
      <li><E:checkered_flag> The end of the exercise</li>
      <li>
        <E:classical_building> The architecture of the software you ran or
        deployed during this exercise
      </li>
      <li>
        <E:boom> Troubleshooting tips: how to fix common problems you might
        encounter
      </li>
    </ul>
    """)
  end

  defp graded_markup,
    do:
      String.trim_trailing("""
      <div>
        <h2 id="graded-exercise">
          <E:trophy> Graded exercise
        </h2>

        <p>
          This exercise will be <strong>graded</strong>. Your submission will be evaluated and will
          contribute to your final grade in this course.
        </p>
      </div>
      """)
end
