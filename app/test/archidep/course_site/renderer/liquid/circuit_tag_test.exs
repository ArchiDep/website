defmodule ArchiDep.CourseSite.Renderer.Liquid.CircuitTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "chapters/411-how-a-computer-works/subject.md"

  describe "render/1" do
    test "shows a circuit with its names and no controls, after its instructions" do
      assert render("""
             {% circuit name: selector %}
             - Turn SELECT on.
             - Flip D1.
             {% endcircuit %}\
             """) ==
               {:ok,
                circuit(
                  ~s(<div class="circuit-instructions"><ul>\n<li>Turn SELECT on.</li>\n<li>Flip D1.</li>\n</ul></div>),
                  ~s(<logic-diagram name="selector" controls="none" names="true"></logic-diagram>)
                ), []}
    end

    test "shows a circuit without instructions alone" do
      assert render("{% circuit name: half-adder %}\n{% endcircuit %}") ==
               {:ok,
                circuit(
                  "",
                  ~s(<logic-diagram name="half-adder" controls="none" names="true"></logic-diagram>)
                ), []}
    end

    test "writes the element's attributes in its own order, and its width as the widest it is drawn" do
      assert render(
               "{% circuit width: 480, speed: slow, name: d-flip-flop-block, inputs: \"DATA=1\", " <>
                 "highlight: true, focus: latch, fixed: true, clock: paused, controls: full, " <>
                 "names: false, autoplay: false, theme: light %}{% endcircuit %}"
             ) ==
               {:ok,
                circuit(
                  "",
                  ~s(<logic-diagram name="d-flip-flop-block" autoplay="false" clock="paused" ) <>
                    ~s(controls="full" fixed focus="latch" highlight="true" inputs="DATA=1" ) <>
                    ~s(names="false" speed="slow" theme="light" style="max-width: 480px">) <>
                    ~s(</logic-diagram>)
                ), []}
    end

    test "expands the Liquid its instructions contain before converting them" do
      assert render("""
             {% circuit name: four-bit-adder %}
             Set A to `0111`, as in the [SFTP exercise]({% link chapters/410-sftp-deployment/exercise.md %}).
             {% endcircuit %}\
             """) ==
               {:ok,
                circuit(
                  ~s(<div class="circuit-instructions"><p>Set A to <code>0111</code>, as in the ) <>
                    ~s(<a href="/2027/course/410-sftp-deployment/">SFTP exercise</a>.</p></div>),
                  ~s(<logic-diagram name="four-bit-adder" controls="none" names="true"></logic-diagram>)
                ), []}
    end

    test "escapes what it writes into the element's attributes" do
      assert render(~s({% circuit name: 'a"b<c' %}{% endcircuit %})) ==
               {:ok,
                circuit(
                  "",
                  ~s(<logic-diagram name="a&quot;b&lt;c" controls="none" names="true"></logic-diagram>)
                ), []}
    end

    test "reports a circuit without a name, and an attribute the element does not have" do
      assert render("{% circuit colour: red, size: 3 %}{% endcircuit %}") ==
               {:ok,
                circuit("", ~s(<logic-diagram controls="none" names="true"></logic-diagram>)),
                [
                  error("A circuit must have a name"),
                  error(~s(Unknown attribute "colour")),
                  error(~s(Unknown attribute "size"))
                ]}
    end

    test "reports a width that is not a number of pixels, and leaves it out" do
      assert render("{% circuit name: counter, width: wide %}{% endcircuit %}") ==
               {:ok,
                circuit(
                  "",
                  ~s(<logic-diagram name="counter" controls="none" names="true"></logic-diagram>)
                ), [error(~s(width must be a number of pixels, not "wide"))]}
    end

    test "reports a fixed that is neither true nor false, and leaves it out" do
      assert render("{% circuit name: counter, fixed: yes %}{% endcircuit %}") ==
               {:ok,
                circuit(
                  "",
                  ~s(<logic-diagram name="counter" controls="none" names="true"></logic-diagram>)
                ), [error(~s(fixed must be true or false, not "yes"))]}
    end

    test "hides the instructions of a circuit whose instructions are only shown enlarged" do
      assert render("""
             {% circuit name: register-bit-block, instructions: enlarged %}
             Turn LOAD on.
             {% endcircuit %}\
             """) ==
               {:ok,
                circuit(
                  ~s(<div class="circuit-instructions" hidden><p>Turn LOAD on.</p></div>),
                  ~s(<logic-diagram name="register-bit-block" controls="none" names="true">) <>
                    ~s(</logic-diagram>)
                ), []}
    end

    test "reports instructions shown neither in the page nor enlarged, and shows them in the page" do
      assert render("""
             {% circuit name: register-bit-block, instructions: never %}
             Turn LOAD on.
             {% endcircuit %}\
             """) ==
               {:ok,
                circuit(
                  ~s(<div class="circuit-instructions"><p>Turn LOAD on.</p></div>),
                  ~s(<logic-diagram name="register-bit-block" controls="none" names="true">) <>
                    ~s(</logic-diagram>)
                ), [error(~s(instructions must be page or enlarged, not "never"))]}
    end
  end

  defp circuit(instructions, element),
    do: ~s(<figure class="circuit">) <> instructions <> element <> ~s(</figure>)

  defp error(message),
    do: RenderError.new({:invalid_tag, "circuit", message}, @source_path, %{line: 1, column: 1})

  defp render(text) do
    Liquid.render(
      CourseSiteFactory.build(:render_context,
        source: CourseSiteFactory.build(:source, text: text),
        source_path: @source_path,
        page: {:document, DocumentRef.new(411, "how-a-computer-works", :subject)},
        urls: CourseSiteFactory.build(:url_context, version: "2027", base_path: "")
      )
    )
  end
end
