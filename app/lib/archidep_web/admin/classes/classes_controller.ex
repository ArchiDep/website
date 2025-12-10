defmodule ArchiDepWeb.Admin.Classes.ClassesController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers.Schemas.Server

  @spec generate_class_csv(Conn.t(), map) :: Conn.t()
  def generate_class_csv(conn, %{"id" => id}) do
    auth = conn.assigns.auth

    case Course.fetch_class(auth, id) do
      {:ok, class} ->
        students = Course.list_students(auth, class)

        server_data = load_server_data_for(students)

        csv =
          students
          |> Enum.map(fn student ->
            {ip_address, username} = Map.get(server_data, student.id, {nil, nil})

            [
              student.name,
              student.academic_class || "",
              student.email,
              ip_address,
              username,
              student.domain,
              ""
            ]
          end)
          |> List.insert_at(0, [
            "name",
            "class",
            "email",
            "ip",
            "username",
            "domain",
            "comments"
          ])
          |> CSV.encode(delimiter: "\n")
          |> Enum.join("")

        conn
        |> put_resp_header("content-type", "text/csv; charset=utf-8")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{class.name}.csv\""
        )
        |> send_resp(200, csv)

      _anything ->
        send_resp(conn, 401, "Unauthorized")
    end
  end

  defp load_server_data_for(students) do
    students
    |> Enum.sort_by(fn %Student{name: name, academic_class: academic_class} ->
      "#{academic_class} - #{name}"
    end)
    |> Enum.map(fn %Student{id: student_id} ->
      Task.async(fn -> find_active_server_data_for(student_id) end)
    end)
    |> Task.await_many()
    |> Enum.reduce(%{}, fn {student_id, ip_address, username}, acc ->
      Map.put(acc, student_id, {ip_address, username})
    end)
  end

  defp find_active_server_data_for(student_id) do
    case Server.find_active_server_for_group_member(student_id) do
      {:ok, server} -> {student_id, server.ip_address, server.username}
      _anything -> {student_id, nil, nil}
    end
  end

  @spec generate_class_ssh_exercise_vm_inventory(Conn.t(), map) :: Conn.t()
  def generate_class_ssh_exercise_vm_inventory(conn, %{"id" => id}) do
    auth = conn.assigns.auth

    case Course.fetch_class(auth, id) do
      {:ok, class} ->
        students = Course.list_students(auth, class)

        conn
        |> put_resp_header("content-type", "application/json; charset=utf-8")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"inventory.yml\""
        )
        |> send_resp(
          200,
          Jason.encode!(
            %{
              "students" =>
                Enum.map(
                  students,
                  &%{"username" => &1.username, "password" => &1.ssh_exercise_password}
                )
            },
            pretty: true
          )
        )

      _anything ->
        send_resp(conn, 401, "Unauthorized")
    end
  end
end
