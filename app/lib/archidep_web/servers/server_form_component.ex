defmodule ArchiDepWeb.Servers.ServerFormComponent do
  @moduledoc """
  Form component for creating or updating servers.
  """

  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr :id, :string, doc: "the id of the form"
  attr :auth, Authentication, doc: "the authentication context"
  attr :form, Form, doc: "the form to render"
  attr :group, ServerGroup, default: nil, doc: "the group to which the server belongs"
  attr :groups, :list, default: nil, doc: "a list of server groups to choose from"
  attr :title, :string, doc: "the title of the form"

  attr :busy, :boolean,
    default: false,
    doc: "whether the server is busy and cannot be updated"

  attr :on_submit, :string, doc: "the event to trigger on form submission"
  attr :on_close, JS, default: nil, doc: "optional JS to execute when the form is closed"
  attr :target, :string, default: nil, doc: "the target for the form submission"

  slot :header,
    required: false,
    doc: "optional header displayed at the top of the form, below the title"

  slot :footer,
    required: false,
    doc: "optional footer displayed at the bottom of the form, above the actions"

  @spec server_form(map()) :: Rendered.t()
  def server_form(assigns) do
    form = assigns[:form]
    provided_group = assigns[:group]
    provided_groups = assigns[:groups] || []

    assigns =
      assign_new(assigns, :selected_group, fn ->
        provided_group ||
          Enum.find(provided_groups, fn group -> group.id == form[:group_id].value end)
      end)

    ~H"""
    <.form id={@id} for={@form} phx-change="validate" phx-submit={@on_submit} phx-target={@target}>
      <fieldset class="fieldset">
        <legend class="fieldset-legend w-full">
          <h3 class="w-full text-lg font-bold">{@title}</h3>
        </legend>

        {render_slot(@header)}

        <label class="fieldset-label mt-2">{gettext("Name")}</label>
        <input
          type="text"
          id={@form[:name].id}
          class="input w-full"
          name={@form[:name].name}
          value={@form[:name].value}
          placeholder={gettext("Give it a name if you like, e.g. My Precious")}
        />
        <.errors_for field={@form[:name]} />

        <%= if @groups do %>
          <label class="fieldset-label required mt-2">{gettext("Group")}</label>
          <select
            id={@form[:group_id].id}
            class="select w-full"
            name={@form[:group_id].name}
            value={@form[:group_id].value}
          >
            <option value="">{gettext("Select a group")}</option>
            <option
              :for={group <- @groups}
              value={group.id}
              selected={@form[:group_id].value == group.id}
            >
              {group.name}
            </option>
          </select>
          <.errors_for field={@form[:group_id]} />
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
        <.errors_for field={@form[:active]} />
      </fieldset>

      <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
        <legend class="fieldset-legend">{gettext("Connection information")}</legend>

        <label class="fieldset-label required mt-2">{gettext("IP address")}</label>
        <input
          type="text"
          id={@form[:ip_address].id}
          class="input w-full"
          name={@form[:ip_address].name}
          value={@form[:ip_address].value}
          placeholder={gettext("e.g. 1.2.3.4")}
        />
        <.errors_for field={@form[:ip_address]} />
        <.field_help>
          {gettext("The public IP address of your cloud server.")}
        </.field_help>

        <label class="fieldset-label required mt-2">{gettext("Username")}</label>
        <input
          type="text"
          id={@form[:username].id}
          class="input w-full"
          name={@form[:username].name}
          value={@form[:username].value}
          placeholder={gettext("e.g. jde")}
        />
        <.errors_for field={@form[:username]} />
        <.field_help>
          {gettext(
            "The name of your Unix user account on the server. This user must be an administrative user account that has sudo privileges without password."
          )}
        </.field_help>

        <%= if root?(@auth) do %>
          <label class="fieldset-label mt-2">{gettext("Application username")}</label>
          <input
            type="text"
            id={@form[:app_username].id}
            class="input w-full"
            name={@form[:app_username].name}
            value={@form[:app_username].value}
          />
          <.errors_for field={@form[:app_username]} />
        <% end %>

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
          placeholder={gettext("22 by default")}
        />
        <.errors_for field={@form[:ssh_port]} />

        <label class="fieldset-label required mt-2">{gettext("SSH host key fingerprints")}</label>
        <textarea
          id={@form[:ssh_host_key_fingerprints].id}
          class="textarea w-full"
          name={@form[:ssh_host_key_fingerprints].name}
          rows="3"
          placeholder={
            gettext(
              "3072 SHA256:x4gxcQl96qBWfIL/8BxVU2WECUuF/TmnHlEQUQcqE7w= root@server (RSA)\n256 SHA256:LTmRTt/Zc7t48a0bF1hI0tlLLOWpIu9c+ZAAytialxw= root@server (ED25519)\n256 SHA256:4wjltFerVQi4J8+rqS3atzUI7jZyUXeuCXhfdH1QKg0= root@server (ECDSA)"
            )
          }
        ><%= @form[:ssh_host_key_fingerprints].value %></textarea>
        <.errors_for field={@form[:ssh_host_key_fingerprints]} />
        <.field_help>
          <div class="flex flex-col gap-2">
            <span>
              {gettext(
                "The fingerprints of your server's SSH host keys, one per line. We will use these to verify that we are connecting to your server and not an attacker's (man-in-the-middle). Simply run the following command {ss}while connected to your server with SSH{se}, and paste the output in the field above:",
                ss: "<strong>",
                se: "</strong>"
              )
              |> raw()}
            </span>
            <code class="pl-2">
              find /etc/ssh -name "ssh_host_*.pub" -exec ssh-keygen -lf {"{}"} \;
            </code>
          </div>
        </.field_help>
      </fieldset>
      <%= if root?(@auth) do %>
        <!-- Expected server properties -->
        <fieldset class="fieldset mt-4 w-full bg-base-300 border-base-200 rounded-box border p-4">
          <legend class="fieldset-legend">Expected properties</legend>
          <div role="alert" class="alert alert-info alert-soft">
            <span class="text-sm">
              {gettext(
                "Warnings will be issued if the server does not meet these expected properties. Default expected properties are inherited from the server's group, but can be overridden here (use 0 or * to unset an expected property)."
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
                      @selected_group,
                      :cpus
                    )
                  ]}
                  name={expected_properties_form[:cpus].name}
                  value={expected_properties_form[:cpus].value}
                  min={if @group == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_group, :cpus, gettext("e.g. 1"))}
                />
                <.errors_for field={expected_properties_form[:cpus]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :cores
                    )
                  ]}
                  name={expected_properties_form[:cores].name}
                  value={expected_properties_form[:cores].value}
                  min={if @group == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_group, :cores, gettext("e.g. 2"))}
                />
                <.errors_for field={expected_properties_form[:cores]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :vcpus
                    )
                  ]}
                  name={expected_properties_form[:vcpus].name}
                  value={expected_properties_form[:vcpus].value}
                  min={if @group == nil, do: "1", else: "0"}
                  placeholder={expected_placeholder(@selected_group, :vcpus, gettext("e.g. 2"))}
                />
                <.errors_for field={expected_properties_form[:vcpus]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                    @selected_group,
                    :memory
                  )
                ]}>
                  <input
                    type="number"
                    id={expected_properties_form[:memory].id}
                    name={expected_properties_form[:memory].name}
                    value={expected_properties_form[:memory].value}
                    min={if @group == nil, do: "1", else: "0"}
                    placeholder={
                      expected_placeholder(
                        @selected_group,
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
                  @selected_group,
                  :memory
                )}
              </div>

              <div>
                <label class="fieldset-label mt-2">{gettext("Swap")}</label>
                <label class={[
                  "input w-full",
                  inherited_input_class(
                    expected_properties_form,
                    @selected_group,
                    :swap
                  )
                ]}>
                  <input
                    type="number"
                    id={expected_properties_form[:swap].id}
                    name={expected_properties_form[:swap].name}
                    value={expected_properties_form[:swap].value}
                    min={if @group == nil, do: "1", else: "0"}
                    placeholder={expected_placeholder(@selected_group, :swap, gettext("e.g. 1024"))}
                  />
                  <span class="label">{gettext("MB")} (±10%)</span>
                </label>
                <.errors_for field={expected_properties_form[:swap]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :system
                    )
                  ]}
                  name={expected_properties_form[:system].name}
                  value={expected_properties_form[:system].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :system,
                      gettext("e.g. Linux")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:system]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :architecture
                    )
                  ]}
                  name={expected_properties_form[:architecture].name}
                  value={expected_properties_form[:architecture].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :architecture,
                      gettext("e.g. x86_64")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:architecture]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :os_family
                    )
                  ]}
                  name={expected_properties_form[:os_family].name}
                  value={expected_properties_form[:os_family].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :os_family,
                      gettext("e.g. Debian")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:os_family]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :distribution
                    )
                  ]}
                  name={expected_properties_form[:distribution].name}
                  value={expected_properties_form[:distribution].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :distribution,
                      gettext("e.g. Ubuntu")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :distribution_release
                    )
                  ]}
                  name={expected_properties_form[:distribution_release].name}
                  value={expected_properties_form[:distribution_release].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :distribution_release,
                      gettext("e.g. noble")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution_release]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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
                      @selected_group,
                      :distribution_version
                    )
                  ]}
                  name={expected_properties_form[:distribution_version].name}
                  value={expected_properties_form[:distribution_version].value}
                  placeholder={
                    expected_placeholder(
                      @selected_group,
                      :distribution_version,
                      gettext("e.g. 24.04")
                    )
                  }
                />
                <.errors_for field={expected_properties_form[:distribution_version]} />
                {inherited_notice(
                  expected_properties_form,
                  @selected_group,
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

  defp expected_placeholder(selected_group, field, default) do
    case Map.get(selected_group.expected_server_properties || %{}, field) do
      nil -> default
      value -> value
    end
  end

  defp inherited_input_class(_form, nil, _field) do
    nil
  end

  defp inherited_input_class(form, selected_group, field) do
    if Map.get(selected_group.expected_server_properties || %{}, field) != nil and
         form[field].value == nil do
      "border-info/85 text-info"
    else
      nil
    end
  end

  defp inherited_notice(form, selected_group, field) do
    group_value =
      case selected_group do
        nil -> nil
        group -> Map.get(group.expected_server_properties || %{}, field)
      end

    assigns = %{
      form: form,
      group_value: group_value,
      field: field
    }

    ~H"""
    <p :if={@group_value != nil} class="label mt-1 italic">
      <%= if @form[@field].value == nil do %>
        <span class="text-info/85">{gettext("Inherited from group")}</span>
      <% else %>
        <span class="text-base-content/50">
          {gettext("Overridden from group (was {value})", value: @group_value)}
        </span>
      <% end %>
    </p>
    """
  end
end
