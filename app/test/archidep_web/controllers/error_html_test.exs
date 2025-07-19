defmodule ArchiDepWeb.Controllers.ErrorHTMLTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  import Phoenix.Template
  alias ArchiDepWeb.Controllers.ErrorHTML

  setup :verify_on_exit!

  test "renders 404.html" do
    assert render_to_string(ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(ErrorHTML, "500", "html", []) ==
             "Internal Server Error"
  end
end
