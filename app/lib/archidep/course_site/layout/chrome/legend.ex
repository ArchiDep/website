defmodule ArchiDep.CourseSite.Layout.Chrome.Legend do
  @moduledoc """
  What the pictures in an exercise mean, shown before the exercise.

  Every exercise annotates its steps with the same handful of pictures, and none
  of them explains itself where it is used. So the key is drawn once, by the
  layout, above every exercise — which is also why no exercise has to remember
  to include it, and why they cannot drift into explaining the same picture
  differently.

  A graded exercise says so first and plainly. Whether an exercise counts
  towards a grade is the thing a reader most needs to know before starting one,
  and it is the kind of fact that is unfair to discover at the end.

  Both headings are the layout's rather than the document's, so their
  identifiers are named by `ArchiDep.CourseSite.Layout.Chrome.Assigns` and read
  from there: whatever lists the page's headings has to agree with them.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  attr :graded?, :boolean, required: true, doc: "whether the exercise counts towards a grade"
  attr :emoji, :map, required: true, doc: "the drawn pictures of the key, by name"

  @doc """
  The key to an exercise's pictures, above the exercise.
  """
  @spec legend(map()) :: Rendered.t()
  def legend(assigns) do
    ~H"""
    <div :if={@graded?}>
      <h2 id={Assigns.heading_id(:graded)}>
        {Phoenix.HTML.raw(@emoji["trophy"])} Graded exercise
      </h2>

      <p>
        This exercise will be <strong>graded</strong>. Your submission will be evaluated and will
        contribute to your final grade in this course.
      </p>
    </div>

    <h2 id={Assigns.heading_id(:legend)}>
      {Phoenix.HTML.raw(@emoji["scroll"])} Legend
    </h2>

    <p>Parts of this exercise are annotated with the following icons:</p>

    <ul class="legend">
      <li>
        {Phoenix.HTML.raw(@emoji["exclamation"])} A task you MUST perform to complete the exercise
      </li>
      <li>
        {Phoenix.HTML.raw(@emoji["question"])} Optional step that you may perform to make sure that
        everything is working correctly, or to set up additional tools that are not required but can
        help you
      </li>
      <li>
        {Phoenix.HTML.raw(@emoji["space_invader"])} Advanced tips on how to go further (or
        challenges!)
      </li>
      <li>{Phoenix.HTML.raw(@emoji["checkered_flag"])} The end of the exercise</li>
      <li>
        {Phoenix.HTML.raw(@emoji["classical_building"])} The architecture of the software you ran or
        deployed during this exercise
      </li>
      <li>
        {Phoenix.HTML.raw(@emoji["boom"])} Troubleshooting tips: how to fix common problems you might
        encounter
      </li>
    </ul>
    """
  end
end
