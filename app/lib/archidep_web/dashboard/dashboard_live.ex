defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    {:ok, student} =
      if has_role?(auth, :student) do
        Course.fetch_authenticated_student(auth)
      else
        {:ok, nil}
      end

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.PubSub.subscribe_student(student.id)
        :ok = Course.PubSub.subscribe_class(student.class_id)
      end
    end

    socket
    |> assign(student: student)
    |> ok()
  end

  @impl LiveView
  def handle_info(
        {:student_updated, %Student{id: student_id} = updated_student},
        %Socket{assigns: %{student: %Student{id: student_id} = student}} = socket
      ),
      do:
        socket
        |> assign(student: Student.refresh!(student, updated_student))
        |> noreply()

  @impl LiveView
  def handle_info(
        {:student_deleted, %Student{id: student_id}},
        %Socket{
          assigns: %{
            student: %Student{id: student_id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil, server_group_member: nil)
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_updated, %Class{id: id} = updated_class},
        %Socket{
          assigns: %{
            student: %Student{class: %Class{id: id} = class} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: %Student{student | class: Class.refresh!(class, updated_class)})
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_deleted, %Class{id: id}},
        %Socket{
          assigns: %{
            student: %Student{class_id: id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil)
        |> noreply()
end
