defmodule ArchiDepWeb.Admin.Classes.Export.KnownHosts do
  @moduledoc """
  The SSH host keys of the students' active servers, as lines of an OpenSSH
  `known_hosts` file: each key is known under both the server's hostname and its
  IP address. The lines are wrapped in comments naming where they come from.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @impl Format
  def id, do: "known-hosts"

  @impl Format
  def label, do: gettext("Known hosts")

  @impl Format
  def filename(class), do: "#{class.name} - known_hosts.txt"

  @impl Format
  def content_type, do: "text/plain; charset=utf-8"

  @impl Format
  def needs_servers?, do: true

  @impl Format
  def included?({_student, server}), do: server != nil

  @impl Format
  def render(%Export{entries: entries} = export, _redact) do
    lines =
      Enum.flat_map(entries, fn {student, server} ->
        hosts =
          Enum.map_join(
            [Export.hostname(student), Export.ip_address(server)],
            ",",
            &host_pattern(&1, server.ssh_port)
          )

        server.ssh_host_keys
        |> SSH.stored_ssh_host_keys()
        |> Enum.map(&"#{hosts} #{SSHHostKey.to_openssh(&1)}")
      end)

    Enum.map_join(
      [header(export)] ++ lines ++ [footer(export)],
      &"#{&1}\n"
    )
  end

  # A host is known on port 22 under its bare name, and on any other port under
  # its name in brackets followed by the port.
  defp host_pattern(host, port) when port in [nil, 22], do: host
  defp host_pattern(host, port), do: "[#{host}]:#{port}"

  defp header(%Export{class: class, generated_at: generated_at}),
    do:
      "# BEGIN SSH host keys of the servers of the ArchiDep students of class #{class.name}, generated #{Calendar.strftime(generated_at, "%Y-%m-%d %H:%M UTC")}"

  defp footer(%Export{class: class}),
    do: "# END SSH host keys of the servers of the ArchiDep students of class #{class.name}"
end
