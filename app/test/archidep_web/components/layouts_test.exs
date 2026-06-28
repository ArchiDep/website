defmodule ArchiDepWeb.Components.LayoutsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Components.Layouts

  @admin_subpaths ["/admin/classes", "/admin/ansible", "/admin/events"]

  describe "app/1" do
    test "an anonymous visitor sees the log-in link and no account or admin navigation" do
      assert shell_projection(nil, "/") == %{
               auth_menu: :log_in,
               top_nav: [{"Course", false}, {"Dashboard", false}],
               admin_submenu: [],
               course_divider?: false,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "a logged-in student sees the account menu and the highlighted dashboard" do
      auth = Factory.build(:authentication, root: false, impersonated_id: nil)

      assert shell_projection(auth, "/app") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", true}],
               admin_submenu: [],
               course_divider?: false,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "an impersonating user also sees the stop-impersonating action" do
      auth = Factory.build(:authentication, root: true, impersonated_id: UUID.generate())

      assert shell_projection(auth, "/app") == %{
               auth_menu: ["Stop impersonating", "Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", true}, {"Admin", false}],
               admin_submenu: [],
               course_divider?: false,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "a root user sees the admin icon but no admin submenu outside the admin section" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert shell_projection(auth, "/app") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", true}, {"Admin", false}],
               admin_submenu: [],
               course_divider?: false,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "a root user in the admin section sees the admin submenu with the classes entry active" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert shell_projection(auth, "/admin/classes") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", false}, {"Admin", true}],
               admin_submenu: [{"Classes", true}, {"Ansible", false}, {"Events", false}],
               course_divider?: true,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "the ansible entry is active on the ansible admin page" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert shell_projection(auth, "/admin/ansible") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", false}, {"Admin", true}],
               admin_submenu: [{"Classes", false}, {"Ansible", true}, {"Events", false}],
               course_divider?: true,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "the events entry is active on the events admin page" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert shell_projection(auth, "/admin/events") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", false}, {"Admin", true}],
               admin_submenu: [{"Classes", false}, {"Ansible", false}, {"Events", true}],
               course_divider?: true,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end

    test "the admin landing page shows the submenu with no entry active" do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      assert shell_projection(auth, "/admin") == %{
               auth_menu: ["Profile", "Log out"],
               top_nav: [{"Course", false}, {"Dashboard", false}, {"Admin", true}],
               admin_submenu: [{"Classes", false}, {"Ansible", false}, {"Events", false}],
               course_divider?: true,
               material_menu?: true,
               content: "PAGE BODY"
             }
    end
  end

  defp shell_projection(auth, path) do
    assigns = %{auth: auth, path: path}

    html =
      rendered_to_string(~H"""
      <Layouts.app flash={%{}} auth={@auth} current_path={@path}>
        <p>PAGE BODY</p>
      </Layouts.app>
      """)

    %{
      auth_menu: auth_menu(html),
      top_nav:
        html
        |> find_html_elements(".menu-horizontal a")
        |> Enum.map(&{html_element_attribute(&1, "data-tip"), highlighted?(&1)}),
      admin_submenu:
        html
        |> find_html_elements("a")
        |> Enum.filter(&(html_element_attribute(&1, "href") in @admin_subpaths))
        |> Enum.map(&{html_element_text(&1), highlighted?(&1)}),
      course_divider?: find_html_elements(html, ".divider") != [],
      material_menu?: find_html_elements(html, "#course-material-menu") != [],
      content: html |> find_html_elements("main") |> List.first() |> html_element_text()
    }
  end

  defp auth_menu(html) do
    if Enum.any?(
         find_html_elements(html, "a"),
         &(html_element_attribute(&1, "href") == "/auth/switch-edu-id/configure")
       ) do
      :log_in
    else
      html |> find_html_elements(".dropdown-content a") |> Enum.map(&html_element_text/1)
    end
  end

  defp highlighted?(element) do
    String.contains?(html_element_attribute(element, "class") || "", "bg-")
  end
end
