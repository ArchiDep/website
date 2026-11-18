defmodule ArchiDepWeb.Admin.Classes.Export.Csv do
  @moduledoc """
  A spreadsheet of the students, with their active server's IP address and
  username, and an empty column for the teacher's comments.
  """

  @behaviour ArchiDepWeb.Admin.Classes.Export.Format

  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Format

  # A spreadsheet application evaluates a cell whose text begins with one of
  # these as a formula when it opens the file, so every cell that carries text
  # someone else wrote is prefixed with an apostrophe to keep it text.
  @csv_formula_prefixes ["=", "+", "-", "@", "\t", "\r"]

  @impl Format
  def id, do: "csv"

  @impl Format
  def label, do: "CSV"

  @impl Format
  def filename(class), do: "#{class.name}.csv"

  @impl Format
  def content_type, do: "text/csv; charset=utf-8"

  @impl Format
  def needs_servers?, do: true

  @impl Format
  def included?(_entry), do: true

  @impl Format
  def render(%Export{entries: entries}, _redact),
    do:
      entries
      |> Enum.map(fn {student, server} ->
        Enum.map(
          [
            student.name,
            student.academic_class || "",
            student.email,
            server && server.ip_address,
            server && server.username,
            student.domain,
            ""
          ],
          &csv_cell/1
        )
      end)
      |> List.insert_at(0, ["name", "class", "email", "ip", "username", "domain", "comments"])
      |> CSV.encode(delimiter: "\n")
      |> Enum.join("")

  defp csv_cell(value) when is_binary(value) do
    if String.starts_with?(value, @csv_formula_prefixes), do: "'" <> value, else: value
  end

  # The IP address is an inet struct and the missing values are `nil`; neither
  # can carry text, so both go through as they are.
  defp csv_cell(value), do: value
end
