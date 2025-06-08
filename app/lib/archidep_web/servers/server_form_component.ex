defmodule ArchiDepWeb.Servers.ServerFormComponent do
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

  def server_form(assigns) do
    ~H"""
    <.form id={@id} for={@form} phx-change="validate" phx-submit={@on_submit} phx-target={@target}>
      <fieldset class="fieldset">
        <legend class="fieldset-legend">
          <h3 class="text-lg font-bold">{@title}</h3>
        </legend>

        <label class="fieldset-label mt-2">Name</label>
        <input
          type="text"
          id={@form[:name].id}
          class="input w-full"
          name={@form[:name].name}
          value={@form[:name].value}
        />
        <.errors_for field={@form[:name]} />

        <label class="fieldset-label mt-2">IP address</label>
        <input
          type="text"
          id={@form[:ip_address].id}
          class="input w-full"
          name={@form[:ip_address].name}
          value={@form[:ip_address].value}
        />
        <.errors_for field={@form[:ip_address]} />

        <label class="fieldset-label mt-2">Username</label>
        <input
          type="text"
          id={@form[:username].id}
          class="input w-full"
          name={@form[:username].name}
          value={@form[:username].value}
        />
        <.errors_for field={@form[:username]} />

        <div class="mt-2 flex justify-end gap-x-2">
          <button type="button" class="btn btn-secondary" phx-click={@on_close}>
            <span class="flex items-center gap-x-2">
              <Heroicons.x_mark class="size-4" />
              <span>Close</span>
            </span>
          </button>
          <button type="submit" class="btn btn-primary">
            <span class="flex items-center gap-x-2">
              <Heroicons.check class="size-4" />
              <span>Save</span>
            </span>
          </button>
        </div>
      </fieldset>
    </.form>
    """
  end
end
