defmodule ArchiDepWeb.Servers.ResetServerSetupDialogLiveTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Servers.ResetServerSetupDialogLive
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket

  describe "id/1" do
    test "builds the dialog id from the server id" do
      server = build(:server_view)

      assert ResetServerSetupDialogLive.id(server) == "reset-server-setup-dialog-#{server.id}"
    end
  end

  describe "open/1" do
    test "opens the dialog of the server" do
      server = build(:server_view)
      dialog_id = "reset-server-setup-dialog-#{server.id}"

      assert ResetServerSetupDialogLive.open(server) ==
               %JS{}
               |> JS.push("opened", target: "##{dialog_id}")
               |> JS.dispatch("open-dialog", detail: %{dialog: dialog_id})
    end
  end

  describe "close/1" do
    test "closes the dialog of the server" do
      server = build(:server_view)
      dialog_id = "reset-server-setup-dialog-#{server.id}"

      assert ResetServerSetupDialogLive.close(server) ==
               %JS{}
               |> JS.push("closed", target: "##{dialog_id}")
               |> JS.dispatch("phx:close-dialog", detail: %{dialog: dialog_id})
    end
  end

  describe "handle_event/3" do
    test "the opened event is a no-op that leaves the socket unchanged" do
      socket = %Socket{}

      assert ResetServerSetupDialogLive.handle_event("opened", %{}, socket) == {:noreply, socket}
    end

    test "the closed event is a no-op that leaves the socket unchanged" do
      socket = %Socket{}

      assert ResetServerSetupDialogLive.handle_event("closed", %{}, socket) == {:noreply, socket}
    end
  end
end
