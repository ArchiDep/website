defmodule ArchiDep.CourseSite.Build.SearchIndexTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.SearchIndex
  alias ArchiDep.CourseSite.Build.SearchIndex.Entry
  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.PageRef
  alias ArchiDep.CourseSite.Urls
  alias ArchiDep.Support.CourseSiteFactory

  describe "entries/4" do
    test "reads a page with no heading as one entry" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2031")
      page = {:document, DocumentRef.new(203, "packages", :subject)}

      html = """
      <p>Installing software on a server.</p>
      <p>And removing it again.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Packages"), html) == [
               %Entry{
                 id: "/course/203-packages/",
                 type: "subject",
                 url: "/2031/course/203-packages/",
                 title: "Packages",
                 subtitle: "Packages",
                 text: "Installing software on a server. And removing it again."
               }
             ]
    end

    test "cuts a page at every top-level heading that carries an identifier" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2032")
      page = {:document, DocumentRef.new(305, "firewall", :exercise)}

      html = """
      <p>A server answers on the ports it is told to.</p>
      <h2 id="opening-a-port">Opening a port</h2>
      <p>Allow the traffic in.</p>
      <h2 id="closing-a-port">Closing a port</h2>
      <p>Deny it again.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Firewall"), html) == [
               %Entry{
                 id: "/course/305-firewall/",
                 type: "exercise",
                 url: "/2032/course/305-firewall/",
                 title: "Firewall",
                 subtitle: "Firewall",
                 text: "A server answers on the ports it is told to."
               },
               %Entry{
                 id: "/course/305-firewall/#opening-a-port",
                 type: "exercise",
                 url: "/2032/course/305-firewall/#opening-a-port",
                 title: "Opening a port",
                 subtitle: "Firewall",
                 text: "Allow the traffic in."
               },
               %Entry{
                 id: "/course/305-firewall/#closing-a-port",
                 type: "exercise",
                 url: "/2032/course/305-firewall/#closing-a-port",
                 title: "Closing a port",
                 subtitle: "Firewall",
                 text: "Deny it again."
               }
             ]
    end

    test "reads a heading with no identifier as prose of the entry it is in" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2033")
      page = {:document, DocumentRef.new(408, "logs", :subject)}

      html = """
      <p>Where a program says what it did.</p>
      <h2>Reading them</h2>
      <p>One line at a time.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Logs"), html) == [
               %Entry{
                 id: "/course/408-logs/",
                 type: "subject",
                 url: "/2033/course/408-logs/",
                 title: "Logs",
                 subtitle: "Logs",
                 text: "Where a program says what it did. Reading them One line at a time."
               }
             ]
    end

    test "reads a heading nested inside a block as prose of the entry it is in" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2034")
      page = {:document, DocumentRef.new(512, "backups", :exercise)}

      html = """
      <p>Copy it somewhere else.</p>
      <div class="note"><h3 id="restoring">Restoring</h3><p>Copy it back.</p></div>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Backups"), html) == [
               %Entry{
                 id: "/course/512-backups/",
                 type: "exercise",
                 url: "/2034/course/512-backups/",
                 title: "Backups",
                 subtitle: "Backups",
                 text: "Copy it somewhere else. RestoringCopy it back."
               }
             ]
    end

    test "keeps a heading that opens a page as prose rather than cutting there" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2035")
      page = {:document, DocumentRef.new(601, "domains", :subject)}

      html = """
      <h2 id="what-a-domain-is">What a domain is</h2>
      <p>A name somebody answers to.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Domains"), html) == [
               %Entry{
                 id: "/course/601-domains/",
                 type: "subject",
                 url: "/2035/course/601-domains/",
                 title: "Domains",
                 subtitle: "Domains",
                 text: "What a domain is A name somebody answers to."
               }
             ]
    end

    test "leaves out a heading that says what the entry it opens is called" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2036")
      page = {:cheatsheet, "systemd"}

      html = """
      <h1 id="systemd">systemd</h1>
      <p>What starts everything else.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "systemd"), html) == [
               %Entry{
                 id: "/cheatsheets/systemd/",
                 type: "cheatsheet",
                 url: "/2036/cheatsheets/systemd/",
                 title: "systemd",
                 subtitle: "systemd",
                 text: "What starts everything else."
               }
             ]
    end

    test "keeps a heading the page ends on, with nothing under it" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2037")
      page = {:document, DocumentRef.new(704, "render", :exercise)}

      html = """
      <p>Somebody else runs the server.</p>
      <h2 id="what-is-left">What is left</h2>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Render"), html) == [
               %Entry{
                 id: "/course/704-render/",
                 type: "exercise",
                 url: "/2037/course/704-render/",
                 title: "Render",
                 subtitle: "Render",
                 text: "Somebody else runs the server."
               },
               %Entry{
                 id: "/course/704-render/#what-is-left",
                 type: "exercise",
                 url: "/2037/course/704-render/#what-is-left",
                 title: "What is left",
                 subtitle: "Render",
                 text: ""
               }
             ]
    end

    test "reads a page with nothing on it as one entry saying nothing" do
      urls = CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2038")
      page = :home

      assert SearchIndex.entries(urls, page, entry(urls, page, "Architecture"), "") == [
               %Entry{
                 id: "/",
                 type: "home",
                 url: "/",
                 title: "Architecture",
                 subtitle: "Architecture",
                 text: ""
               }
             ]
    end

    test "reads the words of a page rather than the spaces between them" do
      urls = CourseSiteFactory.build(:url_context, base_path: "", version: "2039")
      page = {:document, DocumentRef.new(802, "containers", :subject)}

      html = """
      <p>
        An image
        and    a container
      </p>
      <div></div>
      <p>are not the same thing.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Containers"), html) == [
               %Entry{
                 id: "/course/802-containers/",
                 type: "subject",
                 url: "/2039/course/802-containers/",
                 title: "Containers",
                 subtitle: "Containers",
                 text: "An image and a container are not the same thing."
               }
             ]
    end

    test "reads a page under the mount point and the edition it is published at" do
      urls = CourseSiteFactory.build(:url_context, base_path: "/website", version: "2040")
      page = {:document, DocumentRef.new(901, "ansible", :subject)}

      html = """
      <p>Saying what a server should look like.</p>
      <h2 id="playbooks">Playbooks</h2>
      <p>A list of what to do.</p>
      """

      assert SearchIndex.entries(urls, page, entry(urls, page, "Ansible"), html) == [
               %Entry{
                 id: "/course/901-ansible/",
                 type: "subject",
                 url: "/website/2040/course/901-ansible/",
                 title: "Ansible",
                 subtitle: "Ansible",
                 text: "Saying what a server should look like."
               },
               %Entry{
                 id: "/course/901-ansible/#playbooks",
                 type: "subject",
                 url: "/website/2040/course/901-ansible/#playbooks",
                 title: "Playbooks",
                 subtitle: "Ansible",
                 text: "A list of what to do."
               }
             ]
    end

    test "shows a page under what it says of itself and its headings under the page" do
      urls = CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2041")
      page = :home

      html = """
      <p>What you will learn.</p>
      <h2 id="what-you-will-need">What you will need</h2>
      <p>A laptop.</p>
      """

      seed = %Entry{
        entry(urls, page, "Architecture & Deployment")
        | subtitle: "Course home page",
          extra_text: "home home"
      }

      assert SearchIndex.entries(urls, page, seed, html) == [
               %Entry{
                 id: "/",
                 type: "home",
                 url: "/",
                 title: "Architecture & Deployment",
                 subtitle: "Course home page",
                 text: "What you will learn.",
                 extra_text: "home home"
               },
               %Entry{
                 id: "/#what-you-will-need",
                 type: "home",
                 url: "/#what-you-will-need",
                 title: "What you will need",
                 subtitle: "Architecture & Deployment",
                 text: "A laptop."
               }
             ]
    end
  end

  describe "application_entries/1" do
    test "says where the dashboard is on the live site" do
      urls = CourseSiteFactory.build(:url_context, mode: :live, base_path: "", version: "2042")

      assert SearchIndex.application_entries(urls) == [
               %Entry{
                 id: "/app",
                 type: "dashboard",
                 url: "/app",
                 title: "Dashboard",
                 subtitle: "User & server dashboard",
                 text:
                   "Manage your user account for the course and register a server for the exercises."
               }
             ]
    end

    test "says where the dashboard is under the mount point it shares with the site" do
      urls =
        CourseSiteFactory.build(:url_context, mode: :live, base_path: "/website", version: "2043")

      assert SearchIndex.application_entries(urls) == [
               %Entry{
                 id: "/app",
                 type: "dashboard",
                 url: "/website/app",
                 title: "Dashboard",
                 subtitle: "User & server dashboard",
                 text:
                   "Manage your user account for the course and register a server for the exercises."
               }
             ]
    end

    test "holds nothing of the application in a backup copy of the site" do
      urls =
        CourseSiteFactory.build(:url_context,
          mode: :backup,
          base_path: "",
          version: "2044",
          live_site_url: "https://archidep.example.com"
        )

      assert SearchIndex.application_entries(urls) == []
    end

    test "holds nothing of the application in an archived edition" do
      urls =
        CourseSiteFactory.build(:url_context,
          mode: :archive,
          base_path: "",
          version: "2045",
          live_site_url: "https://archidep.example.com"
        )

      assert SearchIndex.application_entries(urls) == []
    end
  end

  # What a page is before it is read: the identity and the wording every entry it
  # contributes is named after. A test that is about something else says only
  # where the page is published, which page it is and what it is called.
  defp entry(urls, page, title),
    do: %Entry{
      id: PageRef.output_path(page),
      type: type(page),
      url: Urls.resolve!(urls, page),
      title: title,
      subtitle: title
    }

  defp type(:home), do: "home"
  defp type({:cheatsheet, _slug}), do: "cheatsheet"
  defp type({:document, %DocumentRef{type: type}}), do: Atom.to_string(type)
end
