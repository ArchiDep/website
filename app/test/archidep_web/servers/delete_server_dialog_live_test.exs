defmodule ArchiDepWeb.Servers.DeleteServerDialogLiveTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Servers.DeleteServerDialogLive
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket

  describe "id/1" do
    test "builds the dialog id from the server id" do
      server = build(:server)

      assert DeleteServerDialogLive.id(server) == "delete-server-dialog-#{server.id}"
    end
  end

  describe "close/1" do
    test "closes the dialog of the server" do
      server = build(:server)
      dialog_id = "delete-server-dialog-#{server.id}"

      assert DeleteServerDialogLive.close(server) ==
               %JS{}
               |> JS.push("closed", target: "##{dialog_id}")
               |> JS.dispatch("phx:close-dialog", detail: %{dialog: dialog_id})
    end
  end

  describe "handle_event/3" do
    test "the closed event is a no-op that leaves the socket unchanged" do
      socket = %Socket{}

      assert DeleteServerDialogLive.handle_event("closed", %{}, socket) == {:noreply, socket}
    end
  end
end
