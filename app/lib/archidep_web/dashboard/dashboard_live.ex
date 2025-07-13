defmodule ArchiDepWeb.Dashboard.DashboardLive do
  alias ArchiDep.Course.Schemas.Class
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive

  @impl true
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [{:ok, student}, {:ok, server_group_member}] =
      if has_role?(auth, :student) do
        Task.await_many([
          Task.async(fn -> Course.fetch_authenticated_student(auth) end),
          Task.async(fn -> Servers.fetch_authenticated_server_group_member(auth) end)
        ])
      else
        [{:ok, nil}, {:ok, nil}]
      end

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.PubSub.subscribe_student(student.id)
        :ok = Course.PubSub.subscribe_class(student.class_id)
        :ok = Servers.PubSub.subscribe_server_group_member(server_group_member.id)
      end
    end

    socket
    |> assign(student: student, server_group_member: server_group_member)
    |> ok()
  end

  @impl true
  def handle_info(
        {:student_updated, updated_student},
        %Socket{assigns: %{student: student, server_group_member: member}} = socket
      ),
      do:
        socket
        |> assign(
          student: Student.refresh!(student, updated_student),
          server_group_member: ServerGroupMember.refresh!(member, updated_student)
        )
        |> noreply()

  @impl true
  def handle_info(
        {:student_deleted, %Student{id: id}},
        %Socket{
          assigns: %{
            student: %Student{id: id},
            server_group_member: %ServerGroupMember{id: id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil, server_group_member: nil)
        |> noreply()

  @impl true
  def handle_info(
        {:class_updated, %Class{id: id} = updated_class},
        %Socket{
          assigns: %{
            student: %Student{class: %Class{id: id} = class} = student,
            server_group_member: %ServerGroupMember{group: %ServerGroup{id: id} = group} = member
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          student: %Student{student | class: Class.refresh!(class, updated_class)},
          server_group_member: %ServerGroupMember{
            member
            | group: ServerGroup.refresh!(group, updated_class)
          }
        )
        |> noreply()

  @impl true
  def handle_info(
        {:class_deleted, %Class{id: id}},
        %Socket{
          assigns: %{
            student: %Student{class_id: id},
            server_group_member: %ServerGroupMember{group_id: id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil, server_group_member: nil)
        |> noreply()

  @impl true
  def handle_info(
        {:server_group_member_updated, updated_member},
        %Socket{assigns: %{student: student, server_group_member: member}} = socket
      ),
      do:
        socket
        |> assign(
          student: Student.refresh!(student, member),
          server_group_member: ServerGroupMember.refresh!(member, updated_member)
        )
        |> noreply()
end
