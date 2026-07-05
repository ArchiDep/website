defmodule ArchiDepWeb.Admin.Classes.ImportStudentsCsvTest do
  use ExUnit.Case, async: true

  alias ArchiDepWeb.Admin.Classes.ImportStudentsCsv

  describe "decode_students_csv/1" do
    test "decodes a well-formed CSV into its header columns and trimmed student rows" do
      lines = ["Name , Email\n", "Alice , alice@example.com\n", "Bob , bob@example.com\n"]

      assert ImportStudentsCsv.decode_students_csv(lines) ==
               {:ok,
                %{
                  columns: ["Name", "Email"],
                  students: [
                    %{"Name" => "Alice", "Email" => "alice@example.com"},
                    %{"Name" => "Bob", "Email" => "bob@example.com"}
                  ]
                }}
    end

    test "returns :not_enough_columns when the header has fewer than two columns" do
      lines = ["Name\n", "Alice\n"]

      assert ImportStudentsCsv.decode_students_csv(lines) == {:error, :not_enough_columns}
    end

    test "returns :no_valid_rows when there are no student rows under the header" do
      lines = ["Name,Email\n"]

      assert ImportStudentsCsv.decode_students_csv(lines) == {:error, :no_valid_rows}
    end

    test "skips rows that fail to parse and keeps the valid ones" do
      lines = [
        "Name,Email\n",
        "Alice,alice@example.org\n",
        "Bob,\"unterminated\n",
        "Carol,carol@example.org\n"
      ]

      assert ImportStudentsCsv.decode_students_csv(lines) ==
               {:ok,
                %{
                  columns: ["Name", "Email"],
                  students: [
                    %{"Name" => "Alice", "Email" => "alice@example.org"},
                    %{"Name" => "Carol", "Email" => "carol@example.org"}
                  ]
                }}
    end
  end

  describe "detect_columns/2" do
    test "detects the email column and takes the first column as the name column" do
      columns = ["Name", "Email"]
      students = [%{"Name" => "Alice", "Email" => "alice@example.com"}]

      assert ImportStudentsCsv.detect_columns(columns, students) ==
               %{email_column: "Email", name_column: "Name"}
    end

    test "takes the second column as the name column when the email column is first" do
      columns = ["Email", "Name"]
      students = [%{"Name" => "Alice", "Email" => "alice@example.com"}]

      assert ImportStudentsCsv.detect_columns(columns, students) ==
               %{email_column: "Email", name_column: "Name"}
    end

    test "picks the column with the most @-containing values as the email column" do
      columns = ["Name", "Email"]

      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "b@d", "Email" => "bob@example.com"}
      ]

      assert ImportStudentsCsv.detect_columns(columns, students) ==
               %{email_column: "Email", name_column: "Name"}
    end
  end
end
