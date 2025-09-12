defmodule ArchiDepWeb.Errors.ErrorHTMLTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  import Phoenix.Template
  alias ArchiDepWeb.Errors.ErrorHTML

  setup :verify_on_exit!

  test "renders 404.html" do
    assert render_to_string(ErrorHTML, "404", "html", []) =~
             "This is not the page you&#39;re looking for."
  end

  test "renders 500.html" do
    assert render_to_string(ErrorHTML, "500", "html", []) =~
             "Oops! Something seems to have gone wrong."
  end
end
