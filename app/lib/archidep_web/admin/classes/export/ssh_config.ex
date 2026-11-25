defmodule ArchiDepWeb.Admin.Classes.Export.SshConfig do
  @moduledoc """
  A block of an OpenSSH client configuration file (`~/.ssh/config`) with a host
  alias for each student's active server, `archidep-st-<username>`, so that
  `ssh archidep-st-<username>` connects to it. The user is the application user
  of a server that has been set up, and the student's own user of one that has
  not, since the application user only exists once setup has created it. The
  block is wrapped in comments naming where it comes from.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @impl Format
  def id, do: "ssh-config"

  @impl Format
  def label, do: gettext("SSH config")

  @impl Format
  def filename(class), do: "#{class.name} - ssh_config.txt"

  @impl Format
  def content_type, do: "text/plain; charset=utf-8"

  @impl Format
  def needs_servers?, do: true

  @impl Format
  def included?({_student, server}), do: server != nil

  @impl Format
  def render(%Export{entries: entries} = export, _redact) do
    hosts =
      Enum.map(entries, fn {student, server} ->
        [
          "Host archidep-st-#{student.username}",
          "  HostName #{Export.ip_address(server)}",
          "  User #{user(server)}"
        ] ++ port(server.ssh_port)
      end)

    Enum.map_join(
      [[header(export)] | Enum.intersperse(hosts, [""])] ++
        [[footer(export)]],
      fn lines -> Enum.map_join(lines, &"#{&1}\n") end
    )
  end

  defp user(server),
    do: if(ServerView.set_up?(server), do: server.app_username, else: server.username)

  defp port(port) when port in [nil, 22], do: []
  defp port(port), do: ["  Port #{port}"]

  defp header(%Export{class: class, generated_at: generated_at}),
    do:
      "# BEGIN SSH host aliases of the servers of the ArchiDep students of class #{class.name}, generated #{Calendar.strftime(generated_at, "%Y-%m-%d %H:%M UTC")}"

  defp footer(%Export{class: class}),
    do: "# END SSH host aliases of the servers of the ArchiDep students of class #{class.name}"
end
