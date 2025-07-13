defmodule ArchiDepWeb.Admin.Classes.StudentFormComponent do
  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr :id, :string, doc: "the id of the form"
  attr :form, Form, doc: "the form to render"
  attr :title, :string, doc: "the title of the form"
  attr :on_submit, :string, doc: "the event to trigger on form submission"
  attr :on_close, JS, default: nil, doc: "optional JS to execute when the form is closed"
  attr :target, :string, default: nil, doc: "the target for the form submission"

  def student_form(assigns) do
    ~H"""
    <.form id={@id} for={@form} phx-change="validate" phx-submit={@on_submit} phx-target={@target}>
      <fieldset class="fieldset">
        <legend class="fieldset-legend">
          <h3 class="text-lg font-bold">{@title}</h3>
        </legend>

        <label class="fieldset-label required mt-2">{gettext("Name")}</label>
        <input
          type="text"
          id={@form[:name].id}
          class="input w-full"
          name={@form[:name].name}
          value={@form[:name].value}
        />
        <.errors_for field={@form[:name]} />

        <label class="fieldset-label required mt-2">{gettext("Email")}</label>
        <input
          type="email"
          id={@form[:email].id}
          class="input w-full"
          name={@form[:email].name}
          value={@form[:email].value}
        />
        <.errors_for field={@form[:email]} />

        <label class="fieldset-label mt-2">{gettext("Academic class")}</label>
        <input
          type="text"
          id={@form[:academic_class].id}
          class="input w-full"
          name={@form[:academic_class].name}
          value={@form[:academic_class].value}
        />
        <.errors_for field={@form[:academic_class]} />
        <.field_help>
          {gettext("Official name of the student's academic class")}
        </.field_help>

        <label class="fieldset-label required mt-2">{gettext("Suggested username")}</label>
        <input
          type="text"
          id={@form[:suggested_username].id}
          class="input w-full"
          name={@form[:suggested_username].name}
          value={@form[:suggested_username].value}
        />
        <.errors_for field={@form[:suggested_username]} />
        <.field_help>
          {gettext("Username that will be suggested to the student for the course (alphanumeric)")}
        </.field_help>

        <label class="fieldset-label required mt-2">{gettext("Domain")}</label>
        <input
          type="text"
          id={@form[:domain].id}
          class="input w-full"
          name={@form[:domain].name}
          value={@form[:domain].value}
          placeholder={gettext("e.g. archidep.ch")}
        />
        <.errors_for field={@form[:domain]} />
        <.field_help>
          {gettext("Domain under which the student will create a subdomain for their server")}
        </.field_help>

        <label class="fieldset-label mt-2">
          <input type="hidden" name={@form[:active].name} value="false" />
          <input
            type="checkbox"
            id={@form[:active].id}
            class="toggle border-error-content bg-error text-error-content/25 checked:border-success-content checked:bg-success checked:text-success-content/50"
            name={@form[:active].name}
            checked={@form[:active].value}
            value="true"
          />
          {gettext("Active")}
        </label>
        <.field_help>
          {gettext(
            "Only active students may log in (their class and user account must also be active)"
          )}
        </.field_help>

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
      </fieldset>
    </.form>
    """
  end
end
