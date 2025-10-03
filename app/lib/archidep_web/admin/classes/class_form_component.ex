defmodule ArchiDepWeb.Admin.Classes.ClassFormComponent do
  @moduledoc """
  Form component for creating or editing classes in the admin interface.
  """

  use ArchiDepWeb, :component

  import ArchiDepWeb.Components.FormComponents
  alias Ecto.Changeset
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true, doc: "the id of the form"
  attr :form, Form, required: true, doc: "the form to render"
  attr :title, :string, required: true, doc: "the title of the form"

  attr :on_add_teacher_ssh_public_key, JS,
    default: nil,
    doc: "the JS command to execute to add a new teacher SSH public key"

  attr :on_submit, :string, required: true, doc: "the event to trigger on form submission"
  attr :on_close, JS, default: nil, doc: "optional JS to execute when the form is closed"
  attr :target, :string, default: nil, doc: "the target for the form submission"

  @spec class_form(map()) :: Rendered.t()
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
        <.field_help>
          {gettext(
            "Students can only log in when enrolled in an active class that has not reached its end date."
          )}
        </.field_help>

        <label class="fieldset-label mt-2">
          <input type="hidden" name={@form[:servers_enabled].name} value="false" />
          <input
            type="checkbox"
            id={@form[:servers_enabled].id}
            class="toggle border-error-content bg-error text-error-content/25 checked:border-success-content checked:bg-success checked:text-success-content/50"
            name={@form[:servers_enabled].name}
            checked={@form[:servers_enabled].value}
            value="true"
          /> {gettext("Servers enabled")}
        </label>
        <.field_help>
          {gettext("Students can only register new servers if their class has servers enabled.")}
        </.field_help>

        <label class="fieldset-label mt-2">{gettext("Teacher SSH public keys")}</label>
        <.inputs_for :let={f} field={@form[:teacher_ssh_public_keys]}>
          <div class="join">
            <input
              type="text"
              id={f[:value].id}
              class="join-item input w-full"
              name={f[:value].name}
              value={f[:value].value}
              placeholder={gettext("Paste an SSH public key here")}
            />
            <label type="button" class="btn btn-neutral join-item">
              <input type="checkbox" name="class[delete_keys][]" value={f.index} class="hidden" />
              <Heroicons.trash class="size-4" />
            </label>
          </div>
          <.errors_for field={f[:value]} />
        </.inputs_for>
        <input type="hidden" name="class[delete_keys][]" />
        <.no_data
          :if={field_empty?(@form[:teacher_ssh_public_keys])}
          class="text-base"
          text={gettext("No keys registered")}
        />
        <.errors_for field={@form[:teacher_ssh_public_keys]} />
        <div class="mt-1">
          <button
            type="button"
            class="btn btn-success btn-sm"
            phx-click="add_teacher_ssh_public_key"
            phx-target={@target}
          >
            <span class="flex items-center gap-x-2">
              <Heroicons.plus class="size-4" />
              <span>{gettext("Add")}</span>
            </span>
          </button>
        </div>

        <label class="fieldset-label mt-2">
          {gettext("SSH exercise VM MD5 host key fingerprints")}
        </label>
        <textarea
          id={@form[:ssh_exercise_vm_md5_host_key_fingerprints].id}
          class="textarea w-full"
          name={@form[:ssh_exercise_vm_md5_host_key_fingerprints].name}
          rows="3"
          placeholder={
            gettext(
              "256 MD5:36:10:41:64:a0:10:0a:ff:e1:49:71:fc:71:74:d4:4c root@server (ED25519)\n256 MD5:8e:b0:cb:56:ed:d1:09:67:d9:88:62:af:60:c0:25:39 root@server (ECDSA)\n3072 MD5:85:29:3c:60:33:4d:36:4b:29:72:27:c1:b8:1e:c5:76 root@server (RSA)"
            )
          }
        ><%= @form[:ssh_exercise_vm_md5_host_key_fingerprints].value %></textarea>
        <.errors_for field={@form[:ssh_exercise_vm_md5_host_key_fingerprints]} />
        <.field_help>
          <code>
            find /etc/ssh -name "*.pub" -exec ssh-keygen -lf {"{}"} -E md5 \;
          </code>
        </.field_help>

        <label class="fieldset-label mt-2">
          {gettext("SSH exercise VM SHA256 host key fingerprints")}
        </label>
        <textarea
          id={@form[:ssh_exercise_vm_sha256_host_key_fingerprints].id}
          class="textarea w-full"
          name={@form[:ssh_exercise_vm_sha256_host_key_fingerprints].name}
          rows="3"
          placeholder={
            gettext(
              "3072 SHA256:x4gxcQl96qBWfIL/8BxVU2WECUuF/TmnHlEQUQcqE7w= root@server (RSA)\n256 SHA256:LTmRTt/Zc7t48a0bF1hI0tlLLOWpIu9c+ZAAytialxw= root@server (ED25519)\n256 SHA256:4wjltFerVQi4J8+rqS3atzUI7jZyUXeuCXhfdH1QKg0= root@server (ECDSA)"
            )
          }
        ><%= @form[:ssh_exercise_vm_sha256_host_key_fingerprints].value %></textarea>
        <.errors_for field={@form[:ssh_exercise_vm_sha256_host_key_fingerprints]} />
        <.field_help>
          <code>
            find /etc/ssh -name "*.pub" -exec ssh-keygen -lf {"{}"} \;
          </code>
        </.field_help>
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

  defp field_empty?(%{value: %{"0" => %{"value" => ""}}}), do: true

  defp field_empty?(field),
    do:
      field.value
      |> Enum.reject(fn x ->
        is_struct(x, Changeset) and x.action == :replace and x.params == nil
      end)
      |> Enum.empty?()
end
