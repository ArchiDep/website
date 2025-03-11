defmodule ArchiDepWeb.ErrorJSONTest do
  use ArchiDepWeb.ConnCase, async: true

  test "renders 404" do
    assert ArchiDepWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ArchiDepWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
