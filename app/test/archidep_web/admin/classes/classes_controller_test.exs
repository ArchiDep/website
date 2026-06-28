defmodule ArchiDepWeb.Admin.Classes.ClassesControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Servers
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

  setup :verify_on_exit!

  describe "GET /admin/classes/:id/csv" do
    setup :register_and_log_in_root

    test "download the students of a class as a CSV file", %{conn: conn, auth: auth} do
      class = CourseFactory.build(:class, name: "Demo Class")

      with_server =
        CourseFactory.build(:student,
          class: class,
          name: "Alice Cidre",
          academic_class: "CS-1",
          email: "alice@example.com",
          domain: "alice.archidep.ch"
        )

      without_server =
        CourseFactory.build(:student,
          class: class,
          name: "Bob Dupont",
          academic_class: nil,
          email: "bob@example.com",
          domain: "bob.archidep.ch"
        )

      server =
        ServersFactory.build(:server,
          username: "user42",
          ip_address: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: 32}
        )

      with_server_id = with_server.id
      without_server_id = without_server.id

      expect(Course.ContextMock, :fetch_class, 1, fn ^auth, class_id ->
        ^class_id = class.id
        {:ok, class}
      end)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class ->
        [with_server, without_server]
      end)

      expect(Servers.ContextMock, :fetch_active_server_for_group_member, 2, fn ^auth,
                                                                               student_id ->
        case student_id do
          ^with_server_id -> {:ok, server}
          ^without_server_id -> {:error, :server_not_found}
        end
      end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/csv")

      ip = to_string(server.ip_address)

      assert download(conn, & &1) == %{
               status: 200,
               content_type: ["text/csv; charset=utf-8"],
               content_disposition: ["attachment; filename=\"Demo Class.csv\""],
               body:
                 "name,class,email,ip,username,domain,comments\n" <>
                   "Alice Cidre,CS-1,alice@example.com,#{ip},user42,alice.archidep.ch,\n" <>
                   "Bob Dupont,,bob@example.com,,,bob.archidep.ch,\n"
             }
    end

    test "download a header-only CSV file for a class with no students", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Empty Class")

      expect(Course.ContextMock, :fetch_class, 1, fn ^auth, class_id ->
        ^class_id = class.id
        {:ok, class}
      end)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class -> [] end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/csv")

      assert download(conn, & &1) == %{
               status: 200,
               content_type: ["text/csv; charset=utf-8"],
               content_disposition: ["attachment; filename=\"Empty Class.csv\""],
               body: "name,class,email,ip,username,domain,comments\n"
             }
    end
  end

  describe "GET /admin/classes/:id/ssh-exercise-vm-inventory" do
    setup :register_and_log_in_root

    test "download the SSH exercise VM inventory of a class as a JSON file", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Demo Class")

      first =
        CourseFactory.build(:student,
          class: class,
          username: "alice",
          ssh_exercise_password: "alice-secret"
        )

      second =
        CourseFactory.build(:student,
          class: class,
          username: "bob",
          ssh_exercise_password: "bob-secret"
        )

      expect(Course.ContextMock, :fetch_class, 1, fn ^auth, class_id ->
        ^class_id = class.id
        {:ok, class}
      end)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class -> [first, second] end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/ssh-exercise-vm-inventory")

      assert download(conn, &Jason.decode!/1) == %{
               status: 200,
               content_type: ["application/json; charset=utf-8"],
               content_disposition: ["attachment; filename=\"inventory.yml\""],
               body: %{
                 "students" => [
                   %{"username" => "alice", "password" => "alice-secret"},
                   %{"username" => "bob", "password" => "bob-secret"}
                 ]
               }
             }
    end

    test "download an empty SSH exercise VM inventory for a class with no students", %{
      conn: conn,
      auth: auth
    } do
      class = CourseFactory.build(:class, name: "Empty Class")

      expect(Course.ContextMock, :fetch_class, 1, fn ^auth, class_id ->
        ^class_id = class.id
        {:ok, class}
      end)

      expect(Course.ContextMock, :list_students, 1, fn ^auth, ^class -> [] end)

      conn = get(conn, ~p"/admin/classes/#{class.id}/ssh-exercise-vm-inventory")

      assert download(conn, &Jason.decode!/1) == %{
               status: 200,
               content_type: ["application/json; charset=utf-8"],
               content_disposition: ["attachment; filename=\"inventory.yml\""],
               body: %{"students" => []}
             }
    end
  end

  describe "anonymous downloads" do
    test "reject the CSV download for an anonymous user", %{conn: conn} do
      class_id = UUID.generate()

      expect(Course.ContextMock, :fetch_class, 1, fn nil, ^class_id ->
        {:error, :class_not_found}
      end)

      conn = get(conn, ~p"/admin/classes/#{class_id}/csv")

      assert response(conn, 401) == "Unauthorized"
    end

    test "reject the SSH exercise VM inventory download for an anonymous user", %{conn: conn} do
      class_id = UUID.generate()

      expect(Course.ContextMock, :fetch_class, 1, fn nil, ^class_id ->
        {:error, :class_not_found}
      end)

      conn = get(conn, ~p"/admin/classes/#{class_id}/ssh-exercise-vm-inventory")

      assert response(conn, 401) == "Unauthorized"
    end
  end

  defp download(conn, body_fun) do
    %{
      status: conn.status,
      content_type: get_resp_header(conn, "content-type"),
      content_disposition: get_resp_header(conn, "content-disposition"),
      body: body_fun.(response(conn, conn.status))
    }
  end
end
