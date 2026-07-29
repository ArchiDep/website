defmodule ArchiDepWeb.Course.ProgressControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]
  import Hammox
  alias ArchiDep.Course.ContextMock

  setup :verify_on_exit!

  describe "GET /api/progress" do
    test "serves what each session of the course recorded, in order", %{conn: conn} do
      sessions = [
        build(:session,
          date: ~D[2025-09-19],
          title: "CLI",
          done: [100, 101],
          due: [102],
          next: [103, 104]
        ),
        build(:session, date: ~D[2025-09-26], title: "SSH", done: [102], due: [], next: [])
      ]

      expect(ContextMock, :course_sessions, fn -> sessions end)

      conn = get(conn, ~p"/api/progress")

      assert json_response(conn, 200) == %{
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
                   "due" => [],
                   "next" => []
                 }
               ]
             }
    end

    test "serves a course that has been taught no session", %{conn: conn} do
      expect(ContextMock, :course_sessions, fn -> [] end)

      conn = get(conn, ~p"/api/progress")

      assert json_response(conn, 200) == %{"sessions" => []}
    end
  end
end
