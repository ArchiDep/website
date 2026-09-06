defmodule ArchiDepWeb.Errors.PlugExceptionTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import ArchiDepWeb.Support.HtmlTestHelpers
  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Errors.UnauthorizedError

  setup :verify_on_exit!

  describe "Plug.Exception for UnauthorizedError" do
    test "maps the error to 403 rather than to the 500 an unmapped error gets" do
      error = %UnauthorizedError{context: :course, action: :list_classes}

      assert {Plug.Exception.status(error), Plug.Exception.actions(error)} == {403, []}
    end
  end

  # The page a student lands on when they follow a link into the admin console.
  # Authorization belongs to the contexts, so the web layer never decides that
  # this request is refused — it only has to answer the error the context raises
  # with something other than a crash. The mock raises what the real policy
  # would (see the Course context's `authorize!`).
  describe "a request whose context refuses the caller" do
    setup :register_and_log_in_student

    test "is answered with the 403 page", %{conn: conn} do
      stub(Course.ContextMock, :fetch_authenticated_student, fn _auth ->
        {:error, :not_a_student}
      end)

      stub(Course.ContextMock, :list_classes, fn _auth ->
        raise UnauthorizedError, context: :course, action: :list_classes
      end)

      {status, _headers, body} =
        assert_error_sent(403, fn -> get(conn, ~p"/admin/classes") end)

      assert {status, error_page(body)} ==
               {403,
                %{
                  title: "403 Forbidden · ArchiDep",
                  status: "403",
                  status_text: "Forbidden",
                  lines: [
                    "You are not allowed to see this page.",
                    "If you think that is a mistake, ask your teacher."
                  ],
                  button: "Take me back to safety!"
                }}
    end
  end

  defp error_page(body) do
    %{
      title: body |> find_html_elements("title") |> Enum.map(&html_element_text/1) |> hd(),
      status: body |> find_html_elements("h1.text-6xl") |> Enum.map(&html_element_text/1) |> hd(),
      status_text: body |> find_html_elements("h2") |> Enum.map(&html_element_text/1) |> hd(),
      lines: body |> find_html_elements("ul li") |> Enum.map(&html_element_text/1),
      button:
        body |> find_html_elements("a.btn-primary") |> Enum.map(&html_element_text/1) |> hd()
    }
  end
end
