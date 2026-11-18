defmodule ArchiDepWeb.Admin.Classes.Export.SshExerciseInventory do
  @moduledoc """
  The usernames and passwords of the students on the SSH exercise virtual
  machine, as the inventory of the Ansible playbook that creates their accounts
  there. It is JSON, which YAML reads as it is.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @impl Format
  def id, do: "ssh-exercise-inventory"

  @impl Format
  def label, do: gettext("SSH exercise inventory")

  @impl Format
  def filename(_class), do: "inventory.yml"

  @impl Format
  def content_type, do: "application/json; charset=utf-8"

  @impl Format
  def needs_servers?, do: false

  @impl Format
  def included?(_entry), do: true

  @impl Format
  def render(%Export{entries: entries}, redact),
    do:
      Jason.encode!(
        %{
          "students" =>
            Enum.map(entries, fn {student, _server} ->
              %{
                "username" => student.username,
                "password" => if(redact, do: "***", else: student.ssh_exercise_password)
              }
            end)
        },
        pretty: true
      )
end
