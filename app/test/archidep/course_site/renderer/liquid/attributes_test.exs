defmodule ArchiDep.CourseSite.Renderer.Liquid.AttributesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Liquid.Attributes

  describe "parse/1" do
    test "reads the attribute lists the course writes" do
      # Every form the content actually uses, since the separator and the
      # quoting of a value are a matter of taste from one tag to the next.
      assert Enum.map(
               [
                 "",
                 "type: tip",
                 "columns: 3",
                 "type: more, id: what-is-npm",
                 "type: more, id:upgrade-restart",
                 "type: advanced, title: Challenge",
                 "title: \"Challenge\"",
                 "type: danger, animate: true",
                 "type: exercise id: forking"
               ],
               &parse/1
             ) == [
               {:ok, %{}},
               {:ok, %{"type" => "tip"}},
               {:ok, %{"columns" => 3}},
               {:ok, %{"type" => "more", "id" => "what-is-npm"}},
               {:ok, %{"type" => "more", "id" => "upgrade-restart"}},
               {:ok, %{"type" => "advanced", "title" => "Challenge"}},
               {:ok, %{"title" => "Challenge"}},
               {:ok, %{"type" => "danger", "animate" => "true"}},
               {:ok, %{"type" => "exercise", "id" => "forking"}}
             ]
    end

    test "reports markup that is not a list of attributes" do
      assert parse("nonsense") ==
               {:error, "Expected a `key: value` attribute", %{line: 1, column: 1}}
    end

    test "reports an attribute whose value is not a value" do
      assert parse("type: ,") ==
               {:error, "Unexpected attribute value", %{line: 1, column: 7}}
    end
  end

  defp parse(markup) do
    {:ok, tokens, _context} =
      Solid.Lexer.tokenize_tag_end(%Solid.ParserContext{
        rest: markup <> " %}",
        line: 1,
        column: 1,
        mode: :normal
      })

    Attributes.parse(tokens)
  end
end
