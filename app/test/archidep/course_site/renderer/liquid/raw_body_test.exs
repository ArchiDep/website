defmodule ArchiDep.CourseSite.Renderer.Liquid.RawBodyTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Liquid.RawBody

  describe "parse/2" do
    test "captures a body without reading any Liquid in it" do
      assert parse("graph TD\n  A --> B\n{% endmermaid %}after", "endmermaid") ==
               {:ok, "graph TD\n  A --> B\n", "after"}
    end

    test "captures a body containing what would otherwise be an expression" do
      assert parse("- name: {{ ansible_hostname }}\n{% endcode %}after", "endcode") ==
               {:ok, "- name: {{ ansible_hostname }}\n", "after"}
    end

    test "captures a body containing a tag of its own" do
      assert parse("{% if x %}{% endcode %}after", "endcode") ==
               {:ok, "{% if x %}", "after"}
    end

    test "drops the whitespace before a closing tag that asks for it" do
      assert parse("echo hi\n{%- endcode %}after", "endcode") == {:ok, "echo hi", "after"}
    end

    test "reports a body that is never closed" do
      assert parse("echo hi\n", "endcode") ==
               {:error, "Tag not terminated, expected {% endcode %}", %{line: 2, column: 1}}
    end
  end

  defp parse(rest, end_tag_name) do
    context = %Solid.ParserContext{rest: rest, line: 1, column: 1, mode: :normal}

    case RawBody.parse(context, end_tag_name) do
      {:ok, body, context} -> {:ok, body, context.rest}
      {:error, reason, loc} -> {:error, reason, loc}
    end
  end
end
