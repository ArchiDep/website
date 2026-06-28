defmodule ArchiDepWeb.Components.Notifications.MessageTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDepWeb.Components.Notifications.Message
  alias Flashy.Normal.Options

  describe "render/1" do
    test "renders an info notification with its colour, message and dismiss progress bar" do
      assert message_projection(Message.new(:info, "Saved")) == %{
               color: ["alert", "alert-info"],
               message: "Saved",
               dismissible?: true
             }
    end

    test "renders a success notification with its colour" do
      assert message_projection(Message.new(:success, "Done")) == %{
               color: ["alert", "alert-success"],
               message: "Done",
               dismissible?: true
             }
    end

    test "renders a warning notification with its colour" do
      assert message_projection(Message.new(:warning, "Careful")) == %{
               color: ["alert", "alert-warning"],
               message: "Careful",
               dismissible?: true
             }
    end

    test "renders an error notification with its colour" do
      assert message_projection(Message.new(:error, "Boom")) == %{
               color: ["alert", "alert-error"],
               message: "Boom",
               dismissible?: true
             }
    end

    test "omits the progress bar for a non-dismissible notification" do
      assert message_projection(Message.new(:info, "Stays", Options.new(dismissible?: false))) ==
               %{color: ["alert", "alert-info"], message: "Stays", dismissible?: false}
    end
  end

  defp message_projection(notification) do
    html = render_component(&Message.render/1, key: "notification", notification: notification)
    [alert] = find_html_elements(html, "[role='alert']")
    [message] = find_html_elements(alert, "span")

    %{
      color: alert |> html_element_attribute("class") |> String.split() |> Enum.sort(),
      message: html_element_text(message),
      dismissible?: html |> find_html_elements("div") |> Enum.any?(&progress_bar?/1)
    }
  end

  defp progress_bar?(element),
    do: String.ends_with?(html_element_attribute(element, "id") || "", "-progress")
end
