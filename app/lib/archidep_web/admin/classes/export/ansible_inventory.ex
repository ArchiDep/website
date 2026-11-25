defmodule ArchiDepWeb.Admin.Classes.Export.AnsibleInventory do
  @moduledoc """
  A YAML Ansible inventory of the students' active servers, in a `students`
  group, each named by the same `archidep-st-<username>` alias as in
  `ArchiDepWeb.Admin.Classes.Export.SshConfig`, with the address, user and port
  Ansible connects to it with. The user is the application user of a server that
  has been set up, and the student's own user of one that has not, since the
  application user only exists once setup has created it.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @impl Format
  def id, do: "ansible-inventory"

  @impl Format
  def label, do: gettext("Ansible inventory")

  @impl Format
  def filename(class), do: "#{class.name} - inventory.yml"

  @impl Format
  def content_type, do: "application/yaml; charset=utf-8"

  @impl Format
  def needs_servers?, do: true

  @impl Format
  def included?({_student, server}), do: server != nil

  @impl Format
  def render(%Export{entries: entries} = export, _redact),
    do:
      Enum.map_join(
        [header(export), "all:", "  children:", "    students:"] ++ hosts(entries),
        &"#{&1}\n"
      )

  defp hosts([]), do: ["      hosts: {}"]

  defp hosts(entries),
    do: [
      "      hosts:"
      | Enum.flat_map(entries, fn {student, server} ->
          [
            "        archidep-st-#{student.username}:",
            "          ansible_host: #{Export.ip_address(server)}",
            "          ansible_user: #{user(server)}"
          ] ++ port(server.ssh_port)
        end)
    ]

  defp user(server),
    do: if(ServerView.set_up?(server), do: server.app_username, else: server.username)

  defp port(port) when port in [nil, 22], do: []
  defp port(port), do: ["          ansible_port: #{port}"]

  defp header(%Export{class: class, generated_at: generated_at}),
    do:
      "# Ansible inventory of the servers of the ArchiDep students of class #{class.name}, generated #{Calendar.strftime(generated_at, "%Y-%m-%d %H:%M UTC")}"
end
