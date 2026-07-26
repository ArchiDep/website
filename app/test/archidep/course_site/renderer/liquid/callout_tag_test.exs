defmodule ArchiDep.CourseSite.Renderer.Liquid.CalloutTagTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Liquid
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "_course/501-nginx/exercise.md"

  describe "render/1" do
    test "shows a callout of every kind under its own icon" do
      assert Map.new(
               ["danger", "exercise", "more", "warning"],
               &{&1, render("{% callout type: #{&1}, id: read-me %}\nDo this.\n{% endcallout %}")}
             ) == %{
               "danger" => {:ok, callout("danger", icon("exclamation-circle")), []},
               "exercise" =>
                 {:ok, callout("exercise", ~s(<div class="icon image">:hammer_and_wrench:</div>)),
                  []},
               "more" =>
                 {:ok, folded_callout("501-nginx:read-me", ":confetti_ball:", "Amazing!"), []},
               "warning" => {:ok, callout("warning", icon("exclamation-triangle")), []}
             }
    end

    test "takes a callout with no kind at all to be a danger" do
      assert render("{% callout %}\nDo this.\n{% endcallout %}") ==
               {:ok, callout("danger", icon("exclamation-circle")), []}
    end

    test "asks for the reader's attention when the callout says to" do
      assert render("{% callout type: warning, animate: true %}\nDo this.\n{% endcallout %}") ==
               {:ok,
                ~s(<div class="callout callout-warning group/callout animate">) <>
                  icon("exclamation-triangle") <>
                  ~s(<div class="container">) <>
                  ~s(<div class="content"><p>Do this.</p></div>) <>
                  ~s(</div></div>), []}
    end

    test "shows a callout of a kind the site has none of as a danger, and reports the kind" do
      assert render("{% callout type: aside %}\nDo this.\n{% endcallout %}") ==
               {:ok, callout("danger", icon("exclamation-circle")),
                [problem(~s(Unknown type "aside"))]}
    end

    test "prefixes the name of a folded callout with the page it is on" do
      assert render("{% callout type: more, id: what-is-nginx %}\nDo this.\n{% endcallout %}") ==
               {:ok, folded_callout("501-nginx:what-is-nginx", ":sparkles:", "Terrific!"), []}
    end

    test "prefixes the name of a folded callout of a cheatsheet with the cheatsheet" do
      assert render("{% callout type: more, id: upgrade-restart %}\nDo this.\n{% endcallout %}",
               page: {:cheatsheet, "sysadmin"}
             ) ==
               {:ok,
                folded_callout(
                  "cheatsheets-sysadmin:upgrade-restart",
                  ":sunglasses:",
                  "Outstanding!"
                ), []}
    end

    test "names a folded callout that names itself nothing after its position, and reports it" do
      assert render("{% callout type: more %}\nDo this.\n{% endcallout %}") ==
               {:ok, folded_callout("501-nginx:callout-1", ":thumbsup:", "Terrific!"),
                [problem(~s(A "more" callout must have an id))]}
    end

    test "names a folded callout whose name is not a slug after its position, and reports it" do
      assert render(~s({% callout type: more, id: "What is Nginx" %}\nDo this.\n{% endcallout %})) ==
               {:ok, folded_callout("501-nginx:callout-1", ":thumbsup:", "Terrific!"),
                [
                  problem(
                    ~s(The id "What is Nginx" must be lowercase alphanumeric words ) <>
                      "separated by hyphens"
                  )
                ]}
    end

    test "renames the second folded callout of a document to take the same name, and reports it" do
      assert render("""
             {% callout type: more, id: what-is-nginx %}
             Do this.
             {% endcallout %}
             {% callout type: more, id: what-is-nginx %}
             Do this.
             {% endcallout %}\
             """) ==
               {:ok,
                folded_callout("501-nginx:what-is-nginx", ":sparkles:", "Terrific!") <>
                  "\n" <> folded_callout("501-nginx:callout-2", ":dizzy:", "Amazing!"),
                [
                  RenderError.new(
                    {:invalid_tag, "callout",
                     ~s(The id "what-is-nginx" is already used in this document)},
                    @source_path,
                    %{line: 4, column: 1}
                  )
                ]}
    end

    test "ignores the name of a callout that is not folded, since it names nothing" do
      assert render("{% callout type: exercise, id: what-is-nginx %}\nDo this.\n{% endcallout %}") ==
               {:ok, callout("exercise", ~s(<div class="icon image">:hammer_and_wrench:</div>)),
                []}
    end

    test "expands the Liquid its prose contains before converting it" do
      assert render("""
             {% callout type: exercise %}
             Read the [SFTP exercise]({% link _course/410-sftp-deployment/exercise.md %}).
             {% endcallout %}\
             """) ==
               {:ok,
                ~s(<div class="callout callout-exercise group/callout">) <>
                  ~s(<div class="icon image">:hammer_and_wrench:</div>) <>
                  ~s(<div class="container">) <>
                  ~s(<div class="content"><p>Read the ) <>
                  ~s(<a href="/2028/course/410-sftp-deployment/">SFTP exercise</a>.</p></div>) <>
                  ~s(</div></div>), []}
    end
  end

  defp callout(type, icon),
    do:
      ~s(<div class="callout callout-#{type} group/callout">) <>
        icon <>
        ~s(<div class="container">) <>
        ~s(<div class="content"><p>Do this.</p></div>) <>
        ~s(</div></div>)

  defp folded_callout(identifier, celebration, congratulations),
    do:
      ~s(<div class="callout callout-more group/callout" data-callout="#{identifier}">) <>
        ~s(<div class="icon image">:books:</div>) <>
        ~s(<div class="container">) <>
        ~s(<input id="callout-#{identifier}" type="checkbox" class="peer hidden" />) <>
        ~s(<div class="content"><p>Do this.</p></div>) <>
        ~s(<label for="callout-#{identifier}" class="more tell-me-more">) <>
        ~s(Would you like to know more?</label>) <>
        ~s(<div class="controls">) <>
        ~s(<label for="callout-#{identifier}" class="less join-item">) <>
        ~s(<span class="mr-1">#{celebration}</span> #{congratulations}</label>) <>
        ~s(<button type="button" class="always-tell-me-more join-item">) <>
        ~s(<span class="mr-1">:books:</span> Always tell me more!</button>) <>
        ~s(</div>) <>
        ~s(<button type="button" class="stop-telling-me-more">) <>
        ~s(<span class="mr-1">:face_with_spiral_eyes:</span> Stop telling me more...</button>) <>
        ~s(</div></div>)

  defp icon(name), do: ~s(<svg class="icon">#{name}</svg>)

  defp problem(message),
    do: RenderError.new({:invalid_tag, "callout", message}, @source_path, %{line: 1, column: 1})

  defp icons do
    {:ok, includes} =
      Renderer.compile_includes(
        Map.new(
          ["exclamation-circle", "exclamation-triangle"],
          &{"icons/#{&1}.html", ~s(<svg class="{{ include.class }}">#{&1}</svg>\n)}
        )
      )

    includes
  end

  defp render(text, attrs \\ []) do
    Liquid.render(
      CourseSiteFactory.build(
        :render_context,
        Keyword.merge(
          [
            source: CourseSiteFactory.build(:source, text: text),
            source_path: @source_path,
            page: {:document, DocumentRef.new(501, "nginx", :exercise)},
            urls: CourseSiteFactory.build(:url_context, version: "2028", base_path: ""),
            includes: icons()
          ],
          attrs
        )
      )
    )
  end
end
