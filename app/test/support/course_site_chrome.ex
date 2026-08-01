defmodule ArchiDep.Support.CourseSiteChrome do
  @moduledoc """
  Drawing one part of the course site's chrome as the string it stands for.

  It is what every test of a chrome component starts with, so it lives here
  rather than in each of them. How those tests then assert what they were given
  is [the subsystem's
  convention](../../lib/archidep/course_site/CONTRIBUTING.md#testing).

  `icon/2` is here because what an icon draws is `Heroicons`' business and not
  the chrome's: a test builds its expectation by asking for one rather than by
  copying out a path nobody here decided on.
  """

  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias Phoenix.LiveView.Rendered

  @doc """
  Draw a component by hand, as the chrome itself draws its two outermost ones.

  A component called from a template is handed the change tracking a live view
  would use; one called by hand is handed a plain map and has to say that there
  is none.
  """
  @spec render((map() -> Rendered.t())) :: String.t()
  @spec render((map() -> Rendered.t()), map()) :: String.t()
  def render(component, assigns \\ %{}),
    do: assigns |> Map.put(:__changed__, nil) |> component.() |> Html.render()

  @doc """
  Draw one of the icons the chrome asks `Heroicons` for.
  """
  @spec icon(atom(), String.t()) :: String.t()
  def icon(name, class), do: render(&apply(Heroicons, name, [&1]), %{class: class})
end
