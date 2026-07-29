defmodule ArchiDep.CourseSite.Build.ProgressFileTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.ProgressFile
  alias ArchiDep.CourseSite.Session

  doctest ArchiDep.CourseSite.Build.ProgressFile

  describe "sessions/1" do
    test "reads the sessions of the course in the order the file lists them" do
      assert ProgressFile.sessions(%{
               "sessions" => [
                 %{
                   "date" => "2025-09-19",
                   "title" => "CLI",
                   "done" => [100, 101],
                   "due" => [102],
                   "next" => [103, 104]
                 },
                 %{
                   "date" => "2025-09-26",
                   "title" => "SSH",
                   "done" => [102],
                   "due" => [103],
                   "next" => []
                 }
               ]
             }) ==
               {:ok,
                [
                  Session.new(~D[2025-09-19], "CLI", [100, 101], [102], [103, 104]),
                  Session.new(~D[2025-09-26], "SSH", [102], [103], [])
                ]}
    end

    test "takes a category a session leaves out to be one it recorded nothing in" do
      assert ProgressFile.sessions(%{
               "sessions" => [%{"date" => "2025-02-08", "title" => "Welcome", "next" => [100]}]
             }) == {:ok, [Session.new(~D[2025-02-08], "Welcome", [], [], [100])]}
    end

    test "reads a course that has been taught no session" do
      assert ProgressFile.sessions(%{"sessions" => []}) == {:ok, []}
    end

    test "refuses a file that records no sessions at all" do
      assert ProgressFile.sessions(%{"version" => 1}) ==
               {:error, {:malformed_progress, ~s{no "sessions" list}}}
    end

    test "refuses a file whose sessions are not a list" do
      assert ProgressFile.sessions(%{"sessions" => %{"2025-09-19" => []}}) ==
               {:error, {:malformed_progress, ~s{"sessions" is not a list}}}
    end

    test "refuses a session that is not an object" do
      assert ProgressFile.sessions(%{"sessions" => ["2025-09-19"]}) ==
               {:error, {:malformed_session, 0, "it is not an object"}}
    end

    test "refuses a session that does not say when it was taught" do
      assert ProgressFile.sessions(%{"sessions" => [%{"title" => "CLI"}]}) ==
               {:error, {:malformed_session, 0, ~s{no "date"}}}
    end

    test "refuses a session whose date is not one" do
      assert ProgressFile.sessions(%{
               "sessions" => [%{"date" => "the 19th", "title" => "CLI"}]
             }) == {:error, {:malformed_session, 0, ~s{"the 19th" is not a date}}}
    end

    test "refuses a session that is not called anything" do
      assert ProgressFile.sessions(%{"sessions" => [%{"date" => "2025-09-19", "title" => ""}]}) ==
               {:error, {:malformed_session, 0, ~s{"" is not a title}}}
    end

    test "refuses a session recording something that is not a chapter number" do
      assert ProgressFile.sessions(%{
               "sessions" => [
                 %{"date" => "2025-09-19", "title" => "CLI", "done" => [100]},
                 %{"date" => "2025-09-26", "title" => "SSH", "due" => ["102"]}
               ]
             }) ==
               {:error,
                {:malformed_session, 1,
                 ~s("due" is ["102"] rather than a list of chapter numbers)}}
    end

    test "refuses a session recording a category that is not a list" do
      assert ProgressFile.sessions(%{
               "sessions" => [%{"date" => "2025-09-19", "title" => "CLI", "done" => 100}]
             }) ==
               {:error,
                {:malformed_session, 0, ~s("done" is 100 rather than a list of chapter numbers)}}
    end
  end
end
