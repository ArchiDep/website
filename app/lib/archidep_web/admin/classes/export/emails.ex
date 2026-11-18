defmodule ArchiDepWeb.Admin.Classes.Export.Emails do
  @moduledoc """
  The email addresses of the students, one per line, e.g. to invite them one by
  one to a service with no bulk invitation.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  use Gettext, backend: ArchiDepWeb.Gettext

  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  @impl Format
  def id, do: "emails"

  @impl Format
  def label, do: gettext("Emails")

  @impl Format
  def filename(class), do: "#{class.name} - emails.txt"

  @impl Format
  def content_type, do: "text/plain; charset=utf-8"

  @impl Format
  def needs_servers?, do: false

  @impl Format
  def included?(_entry), do: true

  @impl Format
  def render(%Export{entries: entries}, _redact),
    do: Enum.map_join(entries, fn {student, _server} -> "#{student.email}\n" end)
end
