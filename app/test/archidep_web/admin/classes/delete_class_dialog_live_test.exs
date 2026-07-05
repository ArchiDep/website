defmodule ArchiDepWeb.Admin.Classes.DeleteClassDialogLiveTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket

  describe "id/1" do
    test "builds the dialog id from the class id" do
      class = build(:class)

      assert DeleteClassDialogLive.id(class) == "delete-class-dialog-#{class.id}"
    end
  end

  describe "close/1" do
    test "closes the dialog of the class" do
      class = build(:class)
      dialog_id = "delete-class-dialog-#{class.id}"

      assert DeleteClassDialogLive.close(class) ==
               %JS{}
               |> JS.push("closed", target: "##{dialog_id}")
               |> JS.dispatch("phx:close-dialog", detail: %{dialog: dialog_id})
    end
  end

  describe "handle_event/3" do
    test "the closed event is a no-op that leaves the socket unchanged" do
      socket = %Socket{}

      assert DeleteClassDialogLive.handle_event("closed", %{}, socket) == {:noreply, socket}
    end
  end
end
