defmodule ArchiDepWeb.Admin.Classes.StudentComponents do
  use ArchiDepWeb, :component

  alias ArchiDep.Course.Schemas.Student

  attr :student, Student, required: true, doc: "the student whose username to display"

  def student_username(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center gap-x-2">
      <span class="font-mono">
        <%= if @student.username do %>
          {@student.username}
        <% else %>
          {@student.suggested_username}
        <% end %>
      </span>
      <span :if={@student.username == nil} class="text-xs italic text-base-content/50">
        ({gettext("suggested")})
      </span>
    </div>
    """
  end
end
