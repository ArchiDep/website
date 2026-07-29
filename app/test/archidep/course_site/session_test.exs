defmodule ArchiDep.CourseSite.SessionTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Session

  doctest ArchiDep.CourseSite.Session

  describe "numbers/2" do
    test "answers for each of the three categories a session records" do
      session = Session.new(~D[2025-10-31], "Basic Deployment", [410, 411], [501], [507, 508])

      assert {
               Session.numbers(session, :done),
               Session.numbers(session, :due),
               Session.numbers(session, :next)
             } == {[410, 411], [501], [507, 508]}
    end
  end
end
