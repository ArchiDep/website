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

        <label class="fieldset-label mt-2">SSH port</label>
        <input
          type="number"
          id={@form[:ssh_port].id}
          class="input w-full"
          name={@form[:ssh_port].name}
          value={@form[:ssh_port].value}
          min="1"
          max="65535"
          step="1"
          placeholder="22"
        />
        <.errors_for field={@form[:ssh_port]} />
      </fieldset>
      <!-- Expected server properties -->
      <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
        <legend class="fieldset-legend">Expected properties</legend>
        <div role="alert" class="alert alert-info alert-soft">
          <span class="text-sm">
            Warnings will be issued if the server does not meet these expected
            properties. Default expected properties are inherited from the
            server's class, but can be overridden here.
          </span>
        </div>
        <!-- CPU -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">CPUs</label>
            <input
              type="text"
              id={@form[:expected_cpus].id}
              class="input w-full"
              name={@form[:expected_cpus].name}
              value={@form[:expected_cpus].value}
              placeholder="e.g. 1"
            />
            <.errors_for field={@form[:expected_cpus]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">CPU cores</label>
            <input
              type="text"
              id={@form[:expected_cores].id}
              class="input w-full"
              name={@form[:expected_cores].name}
              value={@form[:expected_cores].value}
              placeholder="e.g. 2"
            />
            <.errors_for field={@form[:expected_cores]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">vCPUs</label>
            <input
              type="text"
              id={@form[:expected_vcpus].id}
              class="input w-full"
              name={@form[:expected_vcpus].name}
              value={@form[:expected_vcpus].value}
              placeholder="e.g. 2"
            />
            <.errors_for field={@form[:expected_vcpus]} />
          </div>
        </div>
        <!-- Memory -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="fieldset-label mt-2">Memory</label>
            <label class="input w-full">
              <input
                type="text"
                id={@form[:expected_memory].id}
                name={@form[:expected_memory].name}
                value={@form[:expected_memory].value}
                placeholder="e.g. 2048"
              />
              <span class="label">MB</span>
            </label>
            <.errors_for field={@form[:expected_memory]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">Swap</label>
            <label class="input w-full">
              <input
                type="text"
                id={@form[:expected_swap].id}
                name={@form[:expected_swap].name}
                value={@form[:expected_swap].value}
                placeholder="e.g. 1000"
              />
              <span class="label">MB</span>
            </label>
            <.errors_for field={@form[:expected_swap]} />
          </div>
        </div>
        <!-- System, OS family & architecture -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">System</label>
            <input
              type="text"
              id={@form[:expected_system].id}
              class="input w-full"
              name={@form[:expected_system].name}
              value={@form[:expected_system].value}
              placeholder="e.g. Linux"
            />
            <.errors_for field={@form[:expected_system]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">Architecture</label>
            <input
              type="text"
              id={@form[:expected_architecture].id}
              class="input w-full"
              name={@form[:expected_architecture].name}
              value={@form[:expected_architecture].value}
              placeholder="e.g. x86_64"
            />
            <.errors_for field={@form[:expected_architecture]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">OS family</label>
            <input
              type="text"
              id={@form[:expected_os_family].id}
              class="input w-full"
              name={@form[:expected_os_family].name}
              value={@form[:expected_os_family].value}
              placeholder="e.g. Debian"
            />
            <.errors_for field={@form[:expected_os_family]} />
          </div>
        </div>
        <!-- Distribution -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">Distribution</label>
            <input
              type="text"
              id={@form[:expected_distribution].id}
              class="input w-full"
              name={@form[:expected_distribution].name}
              value={@form[:expected_distribution].value}
              placeholder="e.g. Ubuntu"
            />
            <.errors_for field={@form[:expected_distribution]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">Release</label>
            <input
              type="text"
              id={@form[:expected_distribution_release].id}
              class="input w-full"
              name={@form[:expected_distribution_release].name}
              value={@form[:expected_distribution_release].value}
              placeholder="e.g. noble"
            />
            <.errors_for field={@form[:expected_distribution_release]} />
          </div>

          <div>
            <label class="fieldset-label mt-2">Version</label>
            <input
              type="text"
              id={@form[:expected_distribution_version].id}
              class="input w-full"
              name={@form[:expected_distribution_version].name}
              value={@form[:expected_distribution_version].value}
              placeholder="e.g. 24.04"
            />
            <.errors_for field={@form[:expected_distribution_version]} />
          </div>
        </div>
      </fieldset>

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
    </.form>
    """
  end
end
