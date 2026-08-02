defmodule ArchiDepWeb.Course.LatestHTMLTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDepWeb.Course.LatestHTML

  describe "no_equivalent/1" do
    test "offers the way back to the archive when the page came from one" do
      html =
        render_component(&LatestHTML.no_equivalent/1, %{
          flash: %{},
          auth: nil,
          current_path: "/latest",
          home: "/course/",
          archived: "/2025/cheatsheets/unix/"
        })

      assert page(html) == %{
               heading: "This page is no longer part of the course",
               reason:
                 "The page you came from was published by an earlier edition of the course, and the current one has nothing that replaces it.",
               course_link: "/course/",
               archived_link: "/2025/cheatsheets/unix/"
             }
    end

    test "offers only the course when there is no archive to go back to" do
      html =
        render_component(&LatestHTML.no_equivalent/1, %{
          flash: %{},
          auth: nil,
          current_path: "/latest",
          home: "/course/",
          archived: nil
        })

      assert page(html) == %{
               heading: "This page is no longer part of the course",
               reason:
                 "That link does not name a page of any edition of the course we have published.",
               course_link: "/course/",
               archived_link: nil
             }
    end
  end

  defp page(html) do
    %{
      heading: text(html, "#no-equivalent h1"),
      reason: text(html, "#no-equivalent p"),
      course_link: href(html, "#current-course"),
      archived_link: href(html, "#archived-page")
    }
  end

  defp text(html, selector) do
    case find_html_elements(html, selector) do
      [] -> nil
      [element | _rest] -> html_element_text(element)
    end
  end

  defp href(html, selector) do
    case find_html_elements(html, selector) do
      [] -> nil
      [element | _rest] -> html_element_attribute(element, "href")
    end
  end
end
