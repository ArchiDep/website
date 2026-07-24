defmodule ArchiDepWeb.Helpers.LiveViewHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Helpers.LiveViewHelpers

  @auth_principal_id "11111000-0000-0000-0000-000000000000"

  describe "set_process_label/2" do
    test "labels the process with the module and the principal id prefix" do
      auth = Factory.build(:authentication, principal_id: @auth_principal_id)

      assert LiveViewHelpers.set_process_label(__MODULE__, auth) == :ok
      assert :proc_lib.get_label(self()) == "#{__MODULE__}|ua:11111"
    end
  end

  describe "set_process_label/3" do
    test "labels the process with a class context" do
      auth = Factory.build(:authentication, principal_id: @auth_principal_id)
      class = CourseFactory.build(:class, id: "22222000-0000-0000-0000-000000000000")

      assert LiveViewHelpers.set_process_label(__MODULE__, auth, class) == :ok
      assert :proc_lib.get_label(self()) == "#{__MODULE__}|u:11111@cl:22222"
    end

    test "labels the process with a server context" do
      auth = Factory.build(:authentication, principal_id: @auth_principal_id)
      server = ServersFactory.build(:server_view, id: "33333000-0000-0000-0000-000000000000")

      assert LiveViewHelpers.set_process_label(__MODULE__, auth, server) == :ok
      assert :proc_lib.get_label(self()) == "#{__MODULE__}|u:11111@sr:33333"
    end

    test "labels the process with a student context" do
      auth = Factory.build(:authentication, principal_id: @auth_principal_id)
      student = CourseFactory.build(:student_view, id: "44444000-0000-0000-0000-000000000000")

      assert LiveViewHelpers.set_process_label(__MODULE__, auth, student) == :ok
      assert :proc_lib.get_label(self()) == "#{__MODULE__}|u:11111@st:44444"
    end

    test "labels the process with an explicit context string" do
      auth = Factory.build(:authentication, principal_id: @auth_principal_id)

      assert LiveViewHelpers.set_process_label(__MODULE__, auth, "custom-context") == :ok
      assert :proc_lib.get_label(self()) == "#{__MODULE__}|u:11111@custom-context"
    end
  end
end
