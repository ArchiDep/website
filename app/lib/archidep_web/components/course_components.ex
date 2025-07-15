defmodule ArchiDepWeb.Components.CourseComponents do
  use ArchiDepWeb, :component

  alias ArchiDep.Course.Schemas.Student

  attr :student, Student,
    required: true,
    doc: "the student whose username to display"

  def student_username(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center gap-x-2">
      <span class="font-mono">
        {@student.username}
      </span>
      <span :if={not @student.username_confirmed} class="text-xs italic text-base-content/50">
        ({gettext("suggested")})
      </span>
    </div>
    """
  end
end
