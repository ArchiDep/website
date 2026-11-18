defmodule ArchiDepWeb.Admin.Classes.Export.DnsRecords do
  @moduledoc """
  The DNS records of the students' active servers, as lines of the zone files
  of their domains: for each student, a record for their subdomain and a
  wildcard record for the names under it, both with the 5-minute TTL the DNS
  exercise uses. They are grouped by domain, each group under a comment naming
  it, and the whole is wrapped in comments naming where it comes from.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @ttl 300

  @impl Format
  def id, do: "dns-records"

  @impl Format
  def label, do: gettext("DNS records")

  @impl Format
  def filename(class), do: "#{class.name} - DNS records.txt"

  @impl Format
  def content_type, do: "text/plain; charset=utf-8"

  @impl Format
  def needs_servers?, do: true

  @impl Format
  def included?({_student, server}), do: server != nil

  @impl Format
  def render(%Export{entries: entries} = export, _redact) do
    domains =
      entries
      |> Enum.group_by(fn {student, _server} -> student.domain end)
      |> Enum.sort_by(fn {domain, _entries} -> domain end)
      |> Enum.map(fn {domain, domain_entries} ->
        ["; #{domain}" | Enum.flat_map(domain_entries, &records/1)]
      end)

    Enum.map_join(
      [[header(export)] | Enum.intersperse(domains, [""])] ++
        [[footer(export)]],
      fn lines -> Enum.map_join(lines, &"#{&1}\n") end
    )
  end

  defp records({student, server}) do
    type = record_type(server)
    address = Export.ip_address(server)

    [
      "#{student.username} #{@ttl} IN #{type} #{address}",
      "*.#{student.username} #{@ttl} IN #{type} #{address}"
    ]
  end

  defp record_type(%{ip_address: %Postgrex.INET{address: address}})
       when tuple_size(address) == 4,
       do: "A"

  defp record_type(_server), do: "AAAA"

  defp header(%Export{class: class, generated_at: generated_at}),
    do:
      "; BEGIN DNS records of the servers of the ArchiDep students of class #{class.name}, generated #{Calendar.strftime(generated_at, "%Y-%m-%d %H:%M UTC")}"

  defp footer(%Export{class: class}),
    do: "; END DNS records of the servers of the ArchiDep students of class #{class.name}"
end
