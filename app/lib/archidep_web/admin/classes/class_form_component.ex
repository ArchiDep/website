defmodule ArchiDepWeb.Admin.Classes.ClassFormComponent do
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

  def class_form(assigns) do
    ~H"""
    <.form id={@id} for={@form} phx-change="validate" phx-submit={@on_submit} phx-target={@target}>
      <fieldset class="fieldset">
        <legend class="fieldset-legend">
          <h3 class="text-lg font-bold">{@title}</h3>
        </legend>

        <label class="fieldset-label mt-2">{gettext("Name")}</label>
        <input
          type="text"
          id={@form[:name].id}
          class="input w-full"
          name={@form[:name].name}
          value={@form[:name].value}
        />
        <.errors_for field={@form[:name]} />

        <div class="mt-2 grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div>
            <label class="fieldset-label">{gettext("Start date")}</label>
            <input
              type="date"
              id={@form[:start_date].id}
              class="input w-full"
              name={@form[:start_date].name}
              value={@form[:start_date].value}
            />
            <.errors_for field={@form[:start_date]} />
          </div>

          <div>
            <label class="fieldset-label">{gettext("End date")}</label>
            <input
              type="date"
              id={@form[:end_date].id}
              class="input w-full"
              name={@form[:end_date].name}
              value={@form[:end_date].value}
            />
            <.errors_for field={@form[:end_date]} />
          </div>
        </div>

        <label class="fieldset-label mt-2">
          <input type="hidden" name={@form[:active].name} value="false" />
          <input
            type="checkbox"
            id={@form[:active].id}
            class="toggle border-error-content bg-error text-error-content/25 checked:border-success-content checked:bg-success checked:text-success-content/50"
            name={@form[:active].name}
            checked={@form[:active].value}
            value="true"
          /> {gettext("Active")}
        </label>
      </fieldset>
      <!-- Expected server properties -->
      <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
        <legend class="fieldset-legend">{gettext("Expected server properties")}</legend>
        <div role="alert" class="alert alert-info alert-soft">
          <span class="text-sm">
            {gettext(
              "When a student registers a server for this class, warnings will be issued if the server does not meet these expected properties. Leaving a field empty will disable the check for that property. This can be overriden for each server."
            )}
          </span>
        </div>
        <.inputs_for :let={expected_server_properties_form} field={@form[:expected_server_properties]}>
          <!-- CPU -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="fieldset-label mt-2">{gettext("CPUs")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:cpus].id}
                class="input w-full"
                name={expected_server_properties_form[:cpus].name}
                value={expected_server_properties_form[:cpus].value}
                placeholder={gettext("e.g. 1")}
              />
              <.errors_for field={expected_server_properties_form[:cpus]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("CPU cores")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:cores].id}
                class="input w-full"
                name={expected_server_properties_form[:cores].name}
                value={expected_server_properties_form[:cores].value}
                placeholder={gettext("e.g. 2")}
              />
              <.errors_for field={expected_server_properties_form[:cores]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("vCPUs")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:vcpus].id}
                class="input w-full"
                name={expected_server_properties_form[:vcpus].name}
                value={expected_server_properties_form[:vcpus].value}
                placeholder={gettext("e.g. 2")}
              />
              <.errors_for field={expected_server_properties_form[:vcpus]} />
            </div>
          </div>
          <!-- Memory -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="fieldset-label mt-2">{gettext("Memory")}</label>
              <label class="input w-full">
                <input
                  type="text"
                  id={expected_server_properties_form[:memory].id}
                  name={expected_server_properties_form[:memory].name}
                  value={expected_server_properties_form[:memory].value}
                  placeholder={gettext("e.g. 2048")}
                />
                <span class="label">{gettext("MB")} (±10%)</span>
              </label>
              <.errors_for field={expected_server_properties_form[:memory]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("Swap")}</label>
              <label class="input w-full">
                <input
                  type="text"
                  id={expected_server_properties_form[:swap].id}
                  name={expected_server_properties_form[:swap].name}
                  value={expected_server_properties_form[:swap].value}
                  placeholder={gettext("e.g. 1000")}
                />
                <span class="label">{gettext("MB")} (±10%)</span>
              </label>
              <.errors_for field={expected_server_properties_form[:swap]} />
            </div>
          </div>
          <!-- System, OS family & architecture -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="fieldset-label mt-2">{gettext("System")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:system].id}
                class="input w-full"
                name={expected_server_properties_form[:system].name}
                value={expected_server_properties_form[:system].value}
                placeholder={gettext("e.g. Linux")}
              />
              <.errors_for field={expected_server_properties_form[:system]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("Architecture")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:architecture].id}
                class="input w-full"
                name={expected_server_properties_form[:architecture].name}
                value={expected_server_properties_form[:architecture].value}
                placeholder={gettext("e.g. x86_64")}
              />
              <.errors_for field={expected_server_properties_form[:architecture]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("OS family")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:os_family].id}
                class="input w-full"
                name={expected_server_properties_form[:os_family].name}
                value={expected_server_properties_form[:os_family].value}
                placeholder={gettext("e.g. Debian")}
              />
              <.errors_for field={expected_server_properties_form[:os_family]} />
            </div>
          </div>
          <!-- Distribution -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="fieldset-label mt-2">{gettext("Distribution")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:distribution].id}
                class="input w-full"
                name={expected_server_properties_form[:distribution].name}
                value={expected_server_properties_form[:distribution].value}
                placeholder={gettext("e.g. Ubuntu")}
              />
              <.errors_for field={expected_server_properties_form[:distribution]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("Release")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:distribution_release].id}
                class="input w-full"
                name={expected_server_properties_form[:distribution_release].name}
                value={expected_server_properties_form[:distribution_release].value}
                placeholder={gettext("e.g. noble")}
              />
              <.errors_for field={expected_server_properties_form[:distribution_release]} />
            </div>

            <div>
              <label class="fieldset-label mt-2">{gettext("Version")}</label>
              <input
                type="text"
                id={expected_server_properties_form[:distribution_version].id}
                class="input w-full"
                name={expected_server_properties_form[:distribution_version].name}
                value={expected_server_properties_form[:distribution_version].value}
                placeholder={gettext("e.g. 24.04")}
              />
              <.errors_for field={expected_server_properties_form[:distribution_version]} />
            </div>
          </div>
        </.inputs_for>
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
end
