defmodule ArchiDepWeb.ErrorHTMLTest do
  use ArchiDepWeb.ConnCase, async: true

  import Hammox
  import Phoenix.Template

  setup :verify_on_exit!

  test "renders 404.html" do
    assert render_to_string(ArchiDepWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(ArchiDepWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
