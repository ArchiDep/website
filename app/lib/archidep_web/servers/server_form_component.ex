defmodule ArchiDepWeb.Servers.ServerFormComponent do
  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Students.Schemas.Class
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr :id, :string, doc: "the id of the form"
  attr :form, Form, doc: "the form to render"
  attr :class, Class, default: nil, doc: "the class to which the server belongs"
  attr :classes, :list, default: nil, doc: "the list of classes to choose from"
  attr :title, :string, doc: "the title of the form"

  attr :busy, :boolean,
    default: false,
    doc: "whether the server is busy and cannot be updated"

  attr :on_submit, :string, doc: "the event to trigger on form submission"
  attr :on_close, JS, default: nil, doc: "optional JS to execute when the form is closed"
  attr :target, :string, default: nil, doc: "the target for the form submission"

  slot :footer,
    required: false,
    doc: "optional footer displayed at the bottom of the form, above the actions"

  def server_form(assigns) do
    form = assigns[:form]
    provided_class = assigns[:class]
    provided_classes = assigns[:classes] || []

    assigns =
      assigns
      |> assign_new(:selected_class, fn ->
        provided_class ||
          Enum.find(provided_classes, fn class -> class.id == form[:class_id].value end)
      end)

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

        <%= if @classes do %>
          <label class="fieldset-label mt-2">Class</label>
          <select
            id={@form[:class_id].id}
            class="select w-full"
            name={@form[:class_id].name}
            value={@form[:class_id].value}
          >
            <option value="">Select a class</option>
            <option
              :for={class <- @classes}
              value={class.id}
              selected={@form[:class_id].value == class.id}
            >
              {class.name}
            </option>
          </select>
          <.errors_for field={@form[:class_id]} />
        <% end %>

        <label class="fieldset-label mt-2">
          <input type="hidden" name={@form[:active].name} value="false" />
          <input
            type="checkbox"
            id={@form[:active].id}
            class="toggle border-error-content bg-error text-error-content/25 checked:border-success-content checked:bg-success checked:text-success-content/50"
            name={@form[:active].name}
            checked={@form[:active].value}
            value="true"
          /> Active
        </label>
      </fieldset>

      <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
        <legend class="fieldset-legend">Connection information</legend>

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

        <label class="fieldset-label mt-2">Application username</label>
        <input
          type="text"
          id={@form[:app_username].id}
          class="input w-full"
          name={@form[:app_username].name}
          value={@form[:app_username].value}
        />
        <.errors_for field={@form[:app_username]} />

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
            server's class, but can be overridden here (use <code>0</code>
            or <code>*</code>
            to unset an expected property).
          </span>
        </div>
        <!-- CPU -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">CPUs</label>
            <input
              type="number"
              id={@form[:expected_cpus].id}
              class={[
                "input w-full",
                inherited_input_class(@form, @selected_class, :expected_server_cpus, :expected_cpus)
              ]}
              name={@form[:expected_cpus].name}
              value={@form[:expected_cpus].value}
              min={if @class == nil, do: "1", else: "0"}
              placeholder={expected_placeholder(@selected_class, :expected_server_cpus, "e.g. 1")}
            />
            <.errors_for field={@form[:expected_cpus]} />
            {inherited_notice(@form, @selected_class, :expected_server_cpus, :expected_cpus)}
          </div>

          <div>
            <label class="fieldset-label mt-2">CPU cores</label>
            <input
              type="number"
              id={@form[:expected_cores].id}
              class={[
                "input w-full",
                inherited_input_class(@form, @selected_class, :expected_server_cores, :expected_cores)
              ]}
              name={@form[:expected_cores].name}
              value={@form[:expected_cores].value}
              min={if @class == nil, do: "1", else: "0"}
              placeholder={expected_placeholder(@selected_class, :expected_server_cores, "e.g. 2")}
            />
            <.errors_for field={@form[:expected_cores]} />
            {inherited_notice(@form, @selected_class, :expected_server_cores, :expected_cores)}
          </div>

          <div>
            <label class="fieldset-label mt-2">vCPUs</label>
            <input
              type="number"
              id={@form[:expected_vcpus].id}
              class={[
                "input w-full",
                inherited_input_class(@form, @selected_class, :expected_server_vcpus, :expected_vcpus)
              ]}
              name={@form[:expected_vcpus].name}
              value={@form[:expected_vcpus].value}
              min={if @class == nil, do: "1", else: "0"}
              placeholder={expected_placeholder(@selected_class, :expected_server_vcpus, "e.g. 2")}
            />
            <.errors_for field={@form[:expected_vcpus]} />
            {inherited_notice(@form, @selected_class, :expected_server_vcpus, :expected_vcpus)}
          </div>
        </div>
        <!-- Memory -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="fieldset-label mt-2">Memory</label>
            <label class={[
              "input w-full",
              inherited_input_class(
                @form,
                @selected_class,
                :expected_server_memory,
                :expected_memory
              )
            ]}>
              <input
                type="number"
                id={@form[:expected_memory].id}
                name={@form[:expected_memory].name}
                value={@form[:expected_memory].value}
                min={if @class == nil, do: "1", else: "0"}
                placeholder={
                  expected_placeholder(@selected_class, :expected_server_memory, "e.g. 2048")
                }
              />
              <span class="label">MB (±10%)</span>
            </label>
            <.errors_for field={@form[:expected_memory]} />
            {inherited_notice(@form, @selected_class, :expected_server_memory, :expected_memory)}
          </div>

          <div>
            <label class="fieldset-label mt-2">Swap</label>
            <label class={[
              "input w-full",
              inherited_input_class(
                @form,
                @selected_class,
                :expected_server_swap,
                :expected_swap
              )
            ]}>
              <input
                type="number"
                id={@form[:expected_swap].id}
                name={@form[:expected_swap].name}
                value={@form[:expected_swap].value}
                min={if @class == nil, do: "1", else: "0"}
                placeholder={
                  expected_placeholder(@selected_class, :expected_server_swap, "e.g. 1024")
                }
              />
              <span class="label">MB (±10%)</span>
            </label>
            <.errors_for field={@form[:expected_swap]} />
            {inherited_notice(@form, @selected_class, :expected_server_swap, :expected_swap)}
          </div>
        </div>
        <!-- System, OS family & architecture -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">System</label>
            <input
              type="text"
              id={@form[:expected_system].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_system,
                  :expected_system
                )
              ]}
              name={@form[:expected_system].name}
              value={@form[:expected_system].value}
              placeholder={
                expected_placeholder(@selected_class, :expected_server_system, "e.g. Linux")
              }
            />
            <.errors_for field={@form[:expected_system]} />
            {inherited_notice(@form, @selected_class, :expected_server_system, :expected_system)}
          </div>

          <div>
            <label class="fieldset-label mt-2">Architecture</label>
            <input
              type="text"
              id={@form[:expected_architecture].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_architecture,
                  :expected_architecture
                )
              ]}
              name={@form[:expected_architecture].name}
              value={@form[:expected_architecture].value}
              placeholder={
                expected_placeholder(@selected_class, :expected_server_architecture, "e.g. x86_64")
              }
            />
            <.errors_for field={@form[:expected_architecture]} />
            {inherited_notice(
              @form,
              @selected_class,
              :expected_server_architecture,
              :expected_architecture
            )}
          </div>

          <div>
            <label class="fieldset-label mt-2">OS family</label>
            <input
              type="text"
              id={@form[:expected_os_family].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_os_family,
                  :expected_os_family
                )
              ]}
              name={@form[:expected_os_family].name}
              value={@form[:expected_os_family].value}
              placeholder={
                expected_placeholder(@selected_class, :expected_server_os_family, "e.g. Debian")
              }
            />
            <.errors_for field={@form[:expected_os_family]} />
            {inherited_notice(@form, @selected_class, :expected_server_os_family, :expected_os_family)}
          </div>
        </div>
        <!-- Distribution -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="fieldset-label mt-2">Distribution</label>
            <input
              type="text"
              id={@form[:expected_distribution].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_distribution,
                  :expected_distribution
                )
              ]}
              name={@form[:expected_distribution].name}
              value={@form[:expected_distribution].value}
              placeholder={
                expected_placeholder(@selected_class, :expected_server_distribution, "e.g. Ubuntu")
              }
            />
            <.errors_for field={@form[:expected_distribution]} />
            {inherited_notice(
              @form,
              @selected_class,
              :expected_server_distribution,
              :expected_distribution
            )}
          </div>

          <div>
            <label class="fieldset-label mt-2">Release</label>
            <input
              type="text"
              id={@form[:expected_distribution_release].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_distribution_release,
                  :expected_distribution_release
                )
              ]}
              name={@form[:expected_distribution_release].name}
              value={@form[:expected_distribution_release].value}
              placeholder={
                expected_placeholder(
                  @selected_class,
                  :expected_server_distribution_release,
                  "e.g. noble"
                )
              }
            />
            <.errors_for field={@form[:expected_distribution_release]} />
            {inherited_notice(
              @form,
              @selected_class,
              :expected_server_distribution_release,
              :expected_distribution_release
            )}
          </div>

          <div>
            <label class="fieldset-label mt-2">Version</label>
            <input
              type="text"
              id={@form[:expected_distribution_version].id}
              class={[
                "input w-full",
                inherited_input_class(
                  @form,
                  @selected_class,
                  :expected_server_distribution_version,
                  :expected_distribution_version
                )
              ]}
              name={@form[:expected_distribution_version].name}
              value={@form[:expected_distribution_version].value}
              placeholder={
                expected_placeholder(
                  @selected_class,
                  :expected_server_distribution_version,
                  "e.g. 24.04"
                )
              }
            />
            <.errors_for field={@form[:expected_distribution_version]} />
            {inherited_notice(
              @form,
              @selected_class,
              :expected_server_distribution_version,
              :expected_distribution_version
            )}
          </div>
        </div>
      </fieldset>

      {render_slot(@footer)}

      <div class="mt-2 flex justify-end gap-x-2">
        <button type="button" class="btn btn-secondary" phx-click={@on_close}>
          <span class="flex items-center gap-x-2">
            <Heroicons.x_mark class="size-4" />
            <span>Close</span>
          </span>
        </button>
        <button type="submit" class="btn btn-primary" disabled={@busy}>
          <span class="flex items-center gap-x-2">
            <Heroicons.check class="size-4" />
            <span>Save</span>
          </span>
        </button>
      </div>
    </.form>
    """
  end

  @spec expected_placeholder(Class.t(), atom(), String.t()) :: term()

  def expected_placeholder(nil, _class_field, default), do: default

  def expected_placeholder(selected_class, class_field, default) do
    case Map.get(selected_class, class_field) do
      nil -> default
      value -> value
    end
  end

  @spec inherited_notice(
          Form.t(),
          Class.t() | nil,
          atom(),
          atom()
        ) :: String.t() | nil
  def inherited_input_class(form, selected_class, class_field, server_field) do
    if selected_class != nil and Map.get(selected_class, class_field) != nil and
         form[server_field].value == nil do
      "border-info/85 text-info"
    else
      nil
    end
  end

  @spec inherited_notice(
          Form.t(),
          Class.t() | nil,
          atom(),
          atom()
        ) :: Phoenix.LiveView.Rendered.t()
  def inherited_notice(form, selected_class, class_field, server_field) do
    class_value =
      case selected_class do
        nil -> nil
        class -> Map.get(class, class_field)
      end

    assigns = %{
      form: form,
      class_value: class_value,
      server_field: server_field
    }

    ~H"""
    <p :if={@class_value != nil} class="label mt-1 italic">
      <%= if @form[@server_field].value == nil do %>
        <span class="text-info/85">Inherited from class</span>
      <% else %>
        <span class="text-base-content/50">Overridden from class (was {@class_value})</span>
      <% end %>
    </p>
    """
  end
end
