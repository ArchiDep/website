defmodule ArchiDepWeb.Components.Notifications.DisconnectedTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDepWeb.Components.Notifications.Disconnected

  describe "render/1" do
    test "renders the reconnecting warning" do
      html = render_component(&Disconnected.render/1, key: "disconnected")
      [alert] = find_html_elements(html, "[role='alert']")

      assert %{
               color: alert |> html_element_attribute("class") |> String.split() |> Enum.sort(),
               message: html_element_text(alert)
             } == %{
               color: ["alert", "alert-warning"],
               message: "Oops, we've lost the internet; attempting to reconnect..."
             }
    end
  end
end
