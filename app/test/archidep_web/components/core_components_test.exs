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

  describe "emoji/1" do
    test "draws an emoji of the site from the file it is served at" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.emoji name="books" />
        """)

      assert emoji_projection(html) == %{
               src: "/assets/emoji/1f4da.svg",
               alt: "📚",
               class: "emoji"
             }
    end

    test "says what an emoji means, and takes the classes that size it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.emoji name="trophy" alt="Graded exercise" class="size-4" />
        """)

      assert emoji_projection(html) == %{
               src: "/assets/emoji/1f3c6.svg",
               alt: "Graded exercise",
               class: "emoji size-4"
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
               icon: :symbol,
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
               icon: :symbol,
               title: "Note",
               content: "Save your work"
             }
    end

    test "more_note renders the more variant, title and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.more_note>Read the docs</CoreComponents.more_note>
        """)

      assert note_projection(html) == %{
               variant: ["note", "note-more"],
               icon: {:emoji, "📚"},
               title: "More information",
               content: "Read the docs"
             }
    end

    test "troubleshooting_note renders the troubleshooting variant, title and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.troubleshooting_note>Restart the service</CoreComponents.troubleshooting_note>
        """)

      assert note_projection(html) == %{
               variant: ["note", "note-troubleshooting"],
               icon: {:emoji, "💥"},
               title: "Troubleshooting",
               content: "Restart the service"
             }
    end
  end

  describe "data_display/1" do
    test "renders its slot content in a definition list and passes global attributes through" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.data_display id="server-facts">Some data</CoreComponents.data_display>
        """)

      assert data_display_projection(html) == %{content: "Some data", id: "server-facts"}
    end
  end

  defp emoji_projection(html) do
    [emoji] = find_html_elements(html, "img")

    %{
      src: html_element_attribute(emoji, "src"),
      alt: html_element_attribute(emoji, "alt"),
      class: html_element_attribute(emoji, "class")
    }
  end

  defp note_projection(html) do
    [note] = find_html_elements(html, ".note")
    [title] = find_html_elements(note, ".title")
    [content] = find_html_elements(note, ".content")

    %{
      variant: note |> html_element_attribute("class") |> String.split() |> Enum.sort(),
      icon: note_icon(title),
      title: html_element_text(title),
      content: html_element_text(content)
    }
  end

  # A note opens with an icon of the site's own set or with one of its emoji,
  # which is half of what tells one kind of note from another.
  defp note_icon(title) do
    case find_html_elements(title, "img.emoji") do
      [emoji] -> {:emoji, html_element_attribute(emoji, "alt")}
      [] -> if find_html_elements(title, "svg") == [], do: nil, else: :symbol
    end
  end

  defp data_display_projection(html) do
    [dl] = find_html_elements(html, "dl")

    %{content: html_element_text(dl), id: html_element_attribute(dl, "id")}
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
