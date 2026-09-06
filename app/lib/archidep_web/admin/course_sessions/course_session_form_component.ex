defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionFormComponent do
  @moduledoc """
  Form component for recording a session of the course, or correcting one
  already recorded, in the admin interface.
  """

  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @categories [:done, :due, :next]

  attr :id, :string, required: true, doc: "the id of the form"
  attr :form, Form, required: true, doc: "the form to render"
  attr :title, :string, required: true, doc: "the title of the form"
  attr :rows, :list, required: true, doc: "the sections and chapters to offer, as grid rows"
  attr :on_submit, :string, required: true, doc: "the event to trigger on form submission"
  attr :on_close, JS, default: nil, doc: "optional JS to execute when the form is closed"
  attr :target, :string, default: nil, doc: "the target for the form submission"

  @spec course_session_form(map()) :: Rendered.t()
  def course_session_form(assigns) do
    assigns = assign(assigns, :categories, @categories)

    ~H"""
    <.form
      id={@id}
      for={@form}
      phx-change="validate"
      phx-submit={@on_submit}
      phx-target={@target}
    >
      <fieldset class="fieldset">
        <legend class="fieldset-legend">
          <h3 class="text-lg font-bold">{@title}</h3>
        </legend>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label">{gettext("Date")}</label>
            <input
              type="date"
              id={@form[:date].id}
              class="input w-full"
              name={@form[:date].name}
              value={@form[:date].value}
            />
            <.errors_for field={@form[:date]} />
          </div>

          <div class="lg:col-span-2">
            <label class="fieldset-label">{gettext("Title")}</label>
            <input
              type="text"
              id={@form[:title].id}
              class="input w-full"
              name={@form[:title].name}
              value={@form[:title].value}
            />
            <.errors_for field={@form[:title]} />
          </div>
        </div>

        <label class="fieldset-label mt-4">{gettext("What this session covered")}</label>
        <.field_help>
          {gettext(
            "A chapter may be both finished and set as work to hand in, so the three columns are independent."
          )}
        </.field_help>

        <div class="max-h-96 overflow-y-auto">
          <table class="table table-pin-rows table-sm" id={"#{@id}-grid"}>
            <thead>
              <tr>
                <th>{gettext("Section & chapter")}</th>
                <th :for={category <- @categories} class="text-center w-20">
                  {category_label(category)}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :if={@rows == []}>
                <td colspan="1000">
                  <.no_data text={gettext("Every section and chapter of the course is done")} />
                </td>
              </tr>
              <tr
                :for={row <- @rows}
                :key={row.num}
                id={"#{@id}-row-#{row.num}"}
                class={row_class(row)}
              >
                <td>
                  <span class={row.kind == :chapter && "ps-4"}>
                    <span class="font-mono text-xs opacity-60">{row.num}</span>
                    <span :if={row.title}>{row.title}</span>
                    <span :if={row.kind == :orphan} class="italic">
                      {gettext("no longer in the course")}
                    </span>
                  </span>
                </td>
                <td :for={category <- @categories} class="text-center">
                  <input type="hidden" name={box_name(category, row.num)} value="false" />
                  <input
                    type="checkbox"
                    id={"#{@id}-#{category}-#{row.num}"}
                    class="checkbox checkbox-sm"
                    name={box_name(category, row.num)}
                    value="true"
                    checked={checked?(@form[category], row.num)}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <.errors_for :for={category <- @categories} field={@form[category]} />
      </fieldset>

      <div class="mt-2 flex justify-end gap-x-2">
        <button type="button" class="btn btn-secondary" phx-click={@on_close}>
          <span class="flex items-center gap-x-2">
            <Heroicons.x_mark class="size-4" />
            <span>{gettext("Close")}</span>
          </span>
        </button>
        <button type="submit" class="btn btn-primary">
          <span class="flex items-center gap-x-2">
            <Heroicons.check class="size-4" />
            <span>{gettext("Save")}</span>
          </span>
        </button>
      </div>
    </.form>
    """
  end

  defp category_label(:done), do: gettext("Done")
  defp category_label(:due), do: gettext("Due")
  defp category_label(:next), do: gettext("Next")

  defp box_name(category, num), do: "course_session[#{category}][#{num}]"

  defp checked?(%{value: numbers}, num) when is_list(numbers), do: num in numbers
  defp checked?(_field, _num), do: false

  defp row_class(%{kind: :section}), do: "bg-base-200 font-bold"
  defp row_class(%{kind: :chapter}), do: nil
  defp row_class(%{kind: :orphan}), do: "text-warning"
end
