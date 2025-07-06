defmodule ArchiDepWeb.Servers.ServerFormComponent do
  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Students.Schemas.Class
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr :id, :string, doc: "the id of the form"
  attr :auth, Authentication, doc: "the authentication context"
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

        <label class="fieldset-label mt-2">{gettext("Name")}</label>
        <input
          type="text"
          id={@form[:name].id}
          class="input w-full"
          name={@form[:name].name}
          value={@form[:name].value}
        />
        <.errors_for field={@form[:name]} />

        <%= if @class do %>
          <input type="hidden" name={@form[:class_id].name} value={@class.id} />
        <% end %>

        <%= if @classes do %>
          <label class="fieldset-label mt-2">{gettext("Class")}</label>
          <select
            id={@form[:class_id].id}
            class="select w-full"
            name={@form[:class_id].name}
            value={@form[:class_id].value}
          >
            <option value="">{gettext("Select a class")}</option>
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
          />
          {gettext("Active")}
        </label>
      </fieldset>

      <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
        <legend class="fieldset-legend">{gettext("Connection information")}</legend>

        <label class="fieldset-label mt-2">{gettext("IP address")}</label>
        <input
          type="text"
          id={@form[:ip_address].id}
          class="input w-full"
          name={@form[:ip_address].name}
          value={@form[:ip_address].value}
        />
        <.errors_for field={@form[:ip_address]} />

        <label class="fieldset-label mt-2">{gettext("Username")}</label>
        <input
          type="text"
          id={@form[:username].id}
          class="input w-full"
          name={@form[:username].name}
          value={@form[:username].value}
        />
        <.errors_for field={@form[:username]} />

        <label class="fieldset-label mt-2">{gettext("Application username")}</label>
        <input
          type="text"
          id={@form[:app_username].id}
          class="input w-full"
          name={@form[:app_username].name}
          value={@form[:app_username].value}
        />
        <.errors_for field={@form[:app_username]} />

        <label class="fieldset-label mt-2">{gettext("SSH port")}</label>
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
      <%= if has_role?(@auth, :root) do %>
        <!-- Expected server properties -->
        <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
          <legend class="fieldset-legend">Expected properties</legend>
          <div role="alert" class="alert alert-info alert-soft">
            <span class="text-sm">
              {gettext(
                "Warnings will be issued if the server does not meet these expected properties. Default expected properties are inherited from the server's class, but can be overridden here (use 0 or * to unset an expected property)."
              )}
            </span>
          </div>
          <.inputs_for :let={expected_properties_form} field={@form[:expected_properties]}>
            <!-- CPU -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="fieldset-label mt-2">{gettext("CPUs")}</label>
                <input
                  type="number"
                  id={expected_properties_form[:cpus].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :cpus
                    )
                  ]}
                  name={expected_properties_form[:cpus].name}
                  value={expected_properties_form[:cpus].value}
                  min={if @class == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_class, :cpus, gettext("e.g. 1"))}
                />
                <.errors_for field={expected_properties_form[:cpus]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :cpus
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("CPU cores")}</label>
                <input
                  type="number"
                  id={expected_properties_form[:cores].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :cores
                    )
                  ]}
                  name={expected_properties_form[:cores].name}
                  value={expected_properties_form[:cores].value}
                  min={if @class == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_class, :cores, gettext("e.g. 2"))}
                />
                <.errors_for field={expected_properties_form[:cores]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :cores
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("vCPUs")}</label>
                <input
                  type="number"
                  id={expected_properties_form[:vcpus].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :vcpus
                    )
                  ]}
                  name={expected_properties_form[:vcpus].name}
                  value={expected_properties_form[:vcpus].value}
                  min={if @class == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_class, :vcpus, gettext("e.g. 2"))}
                />
                <.errors_for field={expected_properties_form[:vcpus]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :vcpus
                )}
              </div>
            </div>
            <!-- Memory -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="fieldset-label mt-2">{gettext("Memory")}</label>
                <label class={[
                  "input w-full",
                  inherited_input_class(
                    expected_properties_form,
                    @selected_class,
                    :memory
                  )
                ]}>
                  <input
                    type="number"
                    id={expected_properties_form[:memory].id}
                    name={expected_properties_form[:memory].name}
                    value={expected_properties_form[:memory].value}
                    min={if @class == nil, do: "1", else: "0"}
                    placeholder={
                      expected_placeholder(
                        @selected_class,
                        :memory,
                        gettext("e.g. 2048")
                      )
                    }
                  />
                  <span class="label">{gettext("MB")} (±10%)</span>
                </label>
                <.errors_for field={expected_properties_form[:memory]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :memory
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("Swap")}</label>
                <label class={[
                  "input w-full",
                  inherited_input_class(
                    expected_properties_form,
                    @selected_class,
                    :swap
                  )
                ]}>
                  <input
                    type="number"
                    id={expected_properties_form[:swap].id}
                    name={expected_properties_form[:swap].name}
                    value={expected_properties_form[:swap].value}
                    min={if @class == nil, do: "1", else: "0"}
                    placeholder={expected_placeholder(@selected_class, :swap, gettext("e.g. 1024"))}
                  />
                  <span class="label">{gettext("MB")} (±10%)</span>
                </label>
                <.errors_for field={expected_properties_form[:swap]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :swap
                )}
              </div>
            </div>
            <!-- System, OS family & architecture -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="fieldset-label mt-2">{gettext("System")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:system].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :system
                    )
                  ]}
                  name={expected_properties_form[:system].name}
                  value={expected_properties_form[:system].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :system,
                      gettext("e.g. Linux")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:system]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :system
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("Architecture")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:architecture].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :architecture
                    )
                  ]}
                  name={expected_properties_form[:architecture].name}
                  value={expected_properties_form[:architecture].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :architecture,
                      gettext("e.g. x86_64")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:architecture]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :architecture
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("OS family")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:os_family].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :os_family
                    )
                  ]}
                  name={expected_properties_form[:os_family].name}
                  value={expected_properties_form[:os_family].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :os_family,
                      gettext("e.g. Debian")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:os_family]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :os_family
                )}
              </div>
            </div>
            <!-- Distribution -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="fieldset-label mt-2">{gettext("Distribution")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:distribution].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :distribution
                    )
                  ]}
                  name={expected_properties_form[:distribution].name}
                  value={expected_properties_form[:distribution].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :distribution,
                      gettext("e.g. Ubuntu")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :distribution
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("Release")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:distribution_release].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :distribution_release
                    )
                  ]}
                  name={expected_properties_form[:distribution_release].name}
                  value={expected_properties_form[:distribution_release].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :distribution_release,
                      gettext("e.g. noble")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution_release]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :distribution_release
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("Version")}</label>
                <input
                  type="text"
                  id={expected_properties_form[:distribution_version].id}
                  class={[
                    "input w-full",
                    inherited_input_class(
                      expected_properties_form,
                      @selected_class,
                      :distribution_version
                    )
                  ]}
                  name={expected_properties_form[:distribution_version].name}
                  value={expected_properties_form[:distribution_version].value}
                  placeholder={
                    expected_placeholder(
                      @selected_class,
                      :distribution_version,
                      gettext("e.g. 24.04")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution_version]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_class,
                  :distribution_version
                )}
              </div>
            </div>
          </.inputs_for>
        </fieldset>
      <% end %>

      {render_slot(@footer)}

      <div class="mt-2 flex justify-end gap-x-2">
        <button type="button" class="btn btn-secondary" phx-click={@on_close}>
          <span class="flex items-center gap-x-2">
            <Heroicons.x_mark class="size-4" />
            <span>{gettext("Close")}</span>
          </span>
        </button>
        <button type="submit" class="btn btn-primary" disabled={@busy}>
          <span class="flex items-center gap-x-2">
            <Heroicons.check class="size-4" />
            <span>{gettext("Save")}</span>
          </span>
        </button>
      </div>
    </.form>
    """
  end

  defp expected_placeholder(nil, _field, default), do: default

  defp expected_placeholder(selected_class, field, default) do
    case Map.get(selected_class.expected_server_properties, field) do
      nil -> default
      value -> value
    end
  end

  defp inherited_input_class(form, selected_class, field) do
    if selected_class != nil and Map.get(selected_class.expected_server_properties, field) != nil and
         form[field].value == nil do
      "border-info/85 text-info"
    else
      nil
    end
  end

  defp inherited_notice(form, selected_class, field) do
    class_value =
      case selected_class do
        nil -> nil
        class -> Map.get(class.expected_server_properties, field)
      end

    assigns = %{
      form: form,
      class_value: class_value,
      field: field
    }

    ~H"""
    <p :if={@class_value != nil} class="label mt-1 italic">
      <%= if @form[@field].value == nil do %>
        <span class="text-info/85">{gettext("Inherited from class")}</span>
      <% else %>
        <span class="text-base-content/50">
          {gettext("Overridden from class (was {value})", value: @class_value)}
        </span>
      <% end %>
    </p>
    """
  end
end
