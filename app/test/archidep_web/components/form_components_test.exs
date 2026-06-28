defmodule ArchiDepWeb.Components.FormComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.Component, only: [sigil_H: 2, to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2, rendered_to_string: 1]
  alias ArchiDepWeb.Components.FormComponents
  alias Ecto.Changeset

  describe "field_help/1" do
    test "renders its slot content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <FormComponents.field_help>Pick a strong password</FormComponents.field_help>
        """)

      assert rendered_slot_text(html, "div") == "Pick a strong password"
    end
  end

  describe "error/1" do
    test "renders its slot content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <FormComponents.error>Something went wrong</FormComponents.error>
        """)

      assert rendered_slot_text(html, "p") == "Something went wrong"
    end
  end

  describe "translate_error/1" do
    test "interpolates a placeholder through the errors gettext domain" do
      assert FormComponents.translate_error({"should be at most {count} characters", count: 5}) ==
               "should be at most 5 characters"
    end

    test "returns a message without placeholders unchanged" do
      assert FormComponents.translate_error({"cannot be blank", []}) == "cannot be blank"
    end
  end

  describe "process_value/1" do
    test "wraps the stringified value in an :ok tuple" do
      assert FormComponents.process_value(42) == {:ok, "42"}
    end
  end

  describe "errors_for/1" do
    test "renders the translated errors of a used field" do
      assert errors_for_messages(form_field(["is too short"], used: true)) == ["is too short"]
    end

    test "renders every error of a used field, most recent first" do
      assert errors_for_messages(form_field(["is too short", "is invalid"], used: true)) ==
               ["is invalid", "is too short"]
    end

    test "renders no errors for a field that has not been used" do
      assert errors_for_messages(form_field(["is too short"], used: false)) == []
    end
  end

  describe "concurrent_modification_warning/1" do
    test "renders nothing when the new value matches the processed current value" do
      assert cmw_projection(
               render_component(&FormComponents.concurrent_modification_warning/1,
                 current_value: "8",
                 old_value: "8",
                 new_value: "8"
               )
             ) == %{previous: nil, new_badge: nil, text: nil}
    end

    test "renders the modification message, the previous value and the new value as a badge" do
      assert cmw_projection(
               render_component(&FormComponents.concurrent_modification_warning/1,
                 current_value: "8",
                 old_value: "4",
                 new_value: "16"
               )
             ) == %{previous: "4", new_badge: "16", text: "value has been modified 4 16"}
    end

    test "renders the new value raw instead of a badge when the style is :raw" do
      assert cmw_projection(
               render_component(&FormComponents.concurrent_modification_warning/1,
                 current_value: "8",
                 old_value: "4",
                 new_value: "16",
                 new_value_style: :raw
               )
             ) == %{previous: "4", new_badge: nil, text: "value has been modified 4 16"}
    end

    test "hides the previous value when show_old_value is false" do
      assert cmw_projection(
               render_component(&FormComponents.concurrent_modification_warning/1,
                 current_value: "8",
                 old_value: "4",
                 new_value: "16",
                 show_old_value: false
               )
             ) == %{previous: nil, new_badge: "16", text: "value has been modified 16"}
    end

    test "renders the previous and new values through the value_display slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <FormComponents.concurrent_modification_warning current_value="8" old_value="4" new_value="16">
          <:value_display :let={value}>VAL:{value}</:value_display>
        </FormComponents.concurrent_modification_warning>
        """)

      assert cmw_projection(html) == %{
               previous: "VAL:4",
               new_badge: "VAL:16",
               text: "value has been modified VAL:4 VAL:16"
             }
    end
  end

  defp rendered_slot_text(html, selector) do
    [element | _rest] = find_html_elements(html, selector)
    html_element_text(element)
  end

  defp errors_for_messages(field) do
    html = render_component(&FormComponents.errors_for/1, field: field)

    html
    |> find_html_elements("p")
    |> Enum.map(&html_element_text/1)
  end

  defp form_field(error_messages, used: used) do
    with_errors =
      Enum.reduce(
        error_messages,
        Changeset.cast({%{}, %{name: :string}}, %{"name" => "value"}, [:name]),
        fn message, changeset -> Changeset.add_error(changeset, :name, message) end
      )

    changeset =
      if used do
        {:error, applied} = Changeset.apply_action(with_errors, :insert)
        applied
      else
        with_errors
      end

    to_form(changeset, as: :data)[:name]
  end

  defp cmw_projection(html) do
    case find_html_elements(html, "div") do
      [] ->
        %{previous: nil, new_badge: nil, text: nil}

      [container | _rest] ->
        %{
          previous:
            container |> find_html_elements("[data-tip='Previous value']") |> first_text(),
          new_badge: container |> find_html_elements("[data-tip='New value']") |> first_text(),
          text: html_element_text(container)
        }
    end
  end

  defp first_text([]), do: nil
  defp first_text([element | _rest]), do: html_element_text(element)
end
