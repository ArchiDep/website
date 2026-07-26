defmodule ArchiDep.CourseSite.Build.LinkCheckTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Build.LinkCheck
  alias ArchiDep.CourseSite.DocumentRef

  describe "check/2" do
    test "passes a page whose every relative URL leads somewhere" do
      page = {:document, DocumentRef.new(507, "dns", :subject)}

      html = """
      <p><img src="images/zone-a1b2c3.png"><a href="../508-dns-config/">next</a></p>
      """

      files =
        MapSet.new([
          "/course/507-dns/images/zone-a1b2c3.png",
          "/course/508-dns-config/index.html"
        ])

      assert LinkCheck.check([{page, :html, html}], files) == []
    end

    test "reports an image the build wrote nothing for" do
      page = {:document, DocumentRef.new(403, "linux", :subject)}
      html = ~s{<img src="images/missing.png">}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [{page, "images/missing.png", {:missing, "/course/403-linux/images/missing.png"}}]
    end

    test "reports a link to a page the build did not write" do
      page = {:document, DocumentRef.new(404, "unix-basics", :subject)}
      html = ~s{<a href="../405-permissions/">permissions</a>}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [
                 {page, "../405-permissions/", {:missing, "/course/405-permissions/index.html"}}
               ]
    end

    test "reads a link carrying a fragment as a link to the page it names" do
      page = {:document, DocumentRef.new(406, "unix-processes", :subject)}
      html = ~s{<a href="../701-sysadmin-cheatsheet/#installing">how</a>}
      files = MapSet.new(["/course/701-sysadmin-cheatsheet/index.html"])

      assert LinkCheck.check([{page, :html, html}], files) == []
    end

    test "reports a link carrying a fragment whose page the build did not write" do
      page = {:document, DocumentRef.new(407, "pipeline", :subject)}
      html = ~s{<a href="../702-nope/#installing">how</a>}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [
                 {page, "../702-nope/#installing", {:missing, "/course/702-nope/index.html"}}
               ]
    end

    test "reads a URL carrying a query as a link to the path it names" do
      page = {:document, DocumentRef.new(408, "unix-networking", :subject)}
      html = ~s{<a href="images/dns.png?v=2">diagram</a>}
      files = MapSet.new(["/course/408-unix-networking/images/dns.png"])

      assert LinkCheck.check([{page, :html, html}], files) == []
    end

    test "resolves a URL the way it was emitted, percent-encoded" do
      page = {:cheatsheet, "command-line"}
      html = ~s{<a href="pdf/ArchiDep%20103%20-%20Hello%20Shell.pdf">slides</a>}
      files = MapSet.new(["/cheatsheets/command-line/pdf/ArchiDep 103 - Hello Shell.pdf"])

      assert LinkCheck.check([{page, :html, html}], files) == []
    end

    test "reports a URL that climbs above the root of the site" do
      page = {:document, DocumentRef.new(409, "hello-nginx", :subject)}
      html = ~s{<a href="../../../elsewhere/">away</a>}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [{page, "../../../elsewhere/", :escapes_root}]
    end

    test "leaves alone what is not written relative to the page" do
      page = {:document, DocumentRef.new(410, "sftp-deployment", :subject)}

      html = """
      <a href="https://example.com/manual">manual</a>
      <a href="mailto:teacher@example.com">mail</a>
      <a href="/assets/theme/theme-1a2b.css">theme</a>
      <a href="#installing">installing</a>
      <a href="">nothing</a>
      """

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) == []
    end

    test "leaves alone a URL written in a code sample, which a page shows rather than follows" do
      page = {:document, DocumentRef.new(411, "hello-docker", :subject)}
      html = ~s{<pre><code>&lt;a href="nowhere.html"&gt;example&lt;/a&gt;</code></pre>}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) == []
    end

    test "reads a deck as the Markdown it stays, which a parser cannot see into" do
      # A deck is handed to the browser as the text of a `textarea`, so nothing
      # written in it is an element of the page it sits in.
      deck = {:document, DocumentRef.new(201, "git", :slides)}
      page_html = ~s{<textarea><img src='images/missing.png'></textarea>}
      markdown = "<img src='images/missing.png'>\n\n![diagram](images/gone.png)\n"

      assert LinkCheck.check(
               [{deck, :html, page_html}, {deck, :markdown, markdown}],
               MapSet.new()
             ) ==
               [
                 {deck, "images/gone.png", {:missing, "/course/201-git/slides/images/gone.png"}},
                 {deck, "images/missing.png",
                  {:missing, "/course/201-git/slides/images/missing.png"}}
               ]
    end

    test "reports a URL a page writes twice once" do
      page = {:document, DocumentRef.new(412, "hello-compose", :subject)}
      html = ~s{<a href="images/x.png">a</a><img src="images/x.png">}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [{page, "images/x.png", {:missing, "/course/412-hello-compose/images/x.png"}}]
    end

    test "reports what every page of the build got wrong, in one order" do
      first = {:document, DocumentRef.new(302, "image-gallery", :exercise)}
      second = {:cheatsheet, "docker"}

      assert LinkCheck.check(
               [
                 {second, :html, ~s{<img src="images/ps.png">}},
                 {first, :html, ~s{<img src="images/gallery.png">}}
               ],
               MapSet.new()
             ) ==
               [
                 {second, "images/ps.png", {:missing, "/cheatsheets/docker/images/ps.png"}},
                 {first, "images/gallery.png",
                  {:missing, "/course/302-image-gallery/images/gallery.png"}}
               ]
    end

    test "checks a URL written in an attribute no page uses today" do
      page = {:document, DocumentRef.new(413, "hello-swarm", :subject)}
      html = ~s{<video poster="images/cover.jpg"><source srcset="images/wide.jpg"></video>}

      assert LinkCheck.check([{page, :html, html}], MapSet.new()) ==
               [
                 {page, "images/cover.jpg",
                  {:missing, "/course/413-hello-swarm/images/cover.jpg"}},
                 {page, "images/wide.jpg", {:missing, "/course/413-hello-swarm/images/wide.jpg"}}
               ]
    end

    test "checks nothing when the build wrote no page" do
      assert LinkCheck.check([], MapSet.new(["/index.html"])) == []
    end
  end

  describe "format_error/1" do
    test "describes a URL the build wrote nothing for" do
      page = {:document, DocumentRef.new(414, "hello-k8s", :subject)}

      assert LinkCheck.format_error(
               {page, "images/x.png", {:missing, "/course/414-hello-k8s/images/x.png"}}
             ) ==
               ~s{Page /course/414-hello-k8s/ links to "images/x.png", and the build wrote nothing at "/course/414-hello-k8s/images/x.png"}
    end

    test "describes a URL that climbs above the root of the site" do
      assert LinkCheck.format_error({:home, "../../away/", :escapes_root}) ==
               ~s{Page / links to "../../away/", which climbs above the root of the site}
    end
  end
end
