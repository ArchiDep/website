defmodule ArchiDepWeb.Components.CoreComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2, rendered_to_string: 1]
  alias ArchiDepWeb.Components.CoreComponents

  describe "no_data/1" do
    test "renders the default placeholder text" do
      assert no_data_projection([]) == %{text: "-", id: nil}
    end

    test "renders custom placeholder text" do
      assert no_data_projection(text: "n/a") == %{text: "n/a", id: nil}
    end

    test "passes global attributes through to the rendered element" do
      assert no_data_projection(id: "cpu-count") == %{text: "-", id: "cpu-count"}
    end
  end

  describe "data_display_element/1" do
    test "renders its title and slot content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.data_display_element title="Hostname">
          web.example.com
        </CoreComponents.data_display_element>
        """)

      assert data_display_element_projection(html) == %{
               title: "Hostname",
               content: "web.example.com"
             }
    end
  end

  describe "note components" do
    test "warning_note renders the warning variant, title and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.warning_note>Disk almost full</CoreComponents.warning_note>
        """)

      assert note_projection(html) == %{
               variant: ["note", "note-warning"],
               title: "Warning",
               content: "Disk almost full"
             }
    end

    test "info_note renders the info variant, title and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.info_note>Save your work</CoreComponents.info_note>
        """)

      assert note_projection(html) == %{
               variant: ["note", "note-info"],
               title: "Note",
               content: "Save your work"
             }
    end
  end

  defp note_projection(html) do
    [note] = find_html_elements(html, ".note")
    [title] = find_html_elements(note, ".title")
    [content] = find_html_elements(note, ".content")

    %{
      variant: note |> html_element_attribute("class") |> String.split() |> Enum.sort(),
      title: html_element_text(title),
      content: html_element_text(content)
    }
  end

  defp data_display_element_projection(html) do
    [title] = find_html_elements(html, "dt")
    [content] = find_html_elements(html, "dd")

    %{title: html_element_text(title), content: html_element_text(content)}
  end

  defp no_data_projection(assigns) do
    [span] = find_html_elements(render_component(&CoreComponents.no_data/1, assigns), "span")

    %{text: html_element_text(span), id: html_element_attribute(span, "id")}
  end
end
