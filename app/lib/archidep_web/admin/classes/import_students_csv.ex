defmodule ArchiDepWeb.Admin.Classes.ImportStudentsCsv do
  @moduledoc """
  Pure helpers for the student-import dialog: decoding an uploaded CSV into its
  header columns and student rows, and guessing which columns hold the students'
  names and email addresses.
  """

  @type decoded :: %{columns: list(String.t()), students: list(map())}

  @spec decode_students_csv(Enumerable.t()) ::
          {:ok, decoded()} | {:error, :not_enough_columns} | {:error, :no_valid_rows}
  def decode_students_csv(lines) do
    columns =
      lines
      |> CSV.decode(field_transform: &String.trim/1, headers: false)
      |> Enum.flat_map(fn
        {:ok, row} -> [row]
        _malformed_row -> []
      end)
      |> Enum.take(1)
      |> Enum.flat_map(&Function.identity/1)
      |> Enum.filter(fn col -> col != "" end)

    students =
      lines
      |> CSV.decode(field_transform: &String.trim/1, headers: true)
      |> Enum.flat_map(fn
        {:ok, row} -> [Map.filter(row, fn {key, _val} -> key != "" end)]
        _malformed_row -> []
      end)

    cond do
      length(columns) < 2 -> {:error, :not_enough_columns}
      students == [] -> {:error, :no_valid_rows}
      true -> {:ok, %{columns: columns, students: students}}
    end
  end

  @spec detect_columns(list(String.t()), list(map())) :: %{
          email_column: String.t(),
          name_column: String.t()
        }
  def detect_columns(columns, students) do
    email_column =
      columns
      |> Enum.map(fn col ->
        {col,
         Enum.count(students, fn student ->
           student |> Map.get(col, "") |> String.contains?("@")
         end)}
      end)
      |> Enum.sort_by(fn {_col, count} -> -count end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.at(0)

    name_column =
      Enum.at(columns, if(email_column == List.first(columns), do: 1, else: 0))

    %{email_column: email_column, name_column: name_column}
  end
end
