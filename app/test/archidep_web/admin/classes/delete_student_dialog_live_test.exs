defmodule ArchiDepWeb.Admin.Classes.DeleteStudentDialogLiveTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket

  describe "id/1" do
    test "builds the dialog id from the student id" do
      student = build(:student)

      assert DeleteStudentDialogLive.id(student) == "delete-student-dialog-#{student.id}"
    end
  end

  describe "close/1" do
    test "closes the dialog of the student" do
      student = build(:student)
      dialog_id = "delete-student-dialog-#{student.id}"

      assert DeleteStudentDialogLive.close(student) ==
               %JS{}
               |> JS.push("closed", target: "##{dialog_id}")
               |> JS.dispatch("phx:close-dialog", detail: %{dialog: dialog_id})
    end
  end

  describe "handle_event/3" do
    test "the closed event is a no-op that leaves the socket unchanged" do
      socket = %Socket{}

      assert DeleteStudentDialogLive.handle_event("closed", %{}, socket) == {:noreply, socket}
    end
  end
end
