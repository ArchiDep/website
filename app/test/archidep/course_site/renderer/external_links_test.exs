defmodule ArchiDep.CourseSite.Renderer.ExternalLinksTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.ExternalLinks
  alias ArchiDep.Support.CourseSiteFactory

  @elsewhere ~s( target="_blank" rel="noopener noreferrer")

  describe "run/2" do
    test "opens a link to another site in a tab of its own" do
      assert run(~s(<p>Read the <a href="https://man7.org/">manual</a>.</p>)) ==
               {~s(<p>Read the <a href="https://man7.org/"#{@elsewhere}>manual</a>.</p>), []}
    end

    test "opens a link the content writes as HTML of its own" do
      assert run(~s(<p><a href='http://nginx.org/'>nginx.org</a>.</p>)) ==
               {~s(<p><a href='http://nginx.org/'#{@elsewhere}>nginx.org</a>.</p>), []}
    end

    test "opens a link written inside the body of a block tag" do
      assert run(
               ~s(<div class="callout"><div class="content">) <>
                 ~s(<p>See <a href="https://owasp.org/">OWASP</a>.</p></div></div>)
             ) ==
               {~s(<div class="callout"><div class="content">) <>
                  ~s(<p>See <a href="https://owasp.org/"#{@elsewhere}>OWASP</a>.</p></div></div>),
                []}
    end

    test "opens every link of a page that leaves it" do
      assert run(
               ~s(<p><a href="https://man7.org/">one</a> and <a href="https://owasp.org/">two</a>.</p>)
             ) ==
               {~s(<p><a href="https://man7.org/"#{@elsewhere}>one</a> and ) <>
                  ~s(<a href="https://owasp.org/"#{@elsewhere}>two</a>.</p>), []}
    end

    test "leaves a link to another page of the site where it is" do
      assert run(~s(<p>Do the <a href="/2027/course/410-sftp-deployment/">exercise</a>.</p>)) ==
               {~s(<p>Do the <a href="/2027/course/410-sftp-deployment/">exercise</a>.</p>), []}
    end

    test "leaves a link to a heading of the page itself where it is" do
      assert run(~s(<h2 id="ssh">SSH<a href="#ssh" class="anchor"></a></h2>)) ==
               {~s(<h2 id="ssh">SSH<a href="#ssh" class="anchor"></a></h2>), []}
    end

    test "leaves a link to a file next to the page where it is" do
      assert run(~s(<p><a href="./images/architecture.pdf">Download</a></p>)) ==
               {~s(<p><a href="./images/architecture.pdf">Download</a></p>), []}
    end

    test "leaves a link to the site itself where it is, in a build that writes URLs in full" do
      assert run(
               ~s(<p><a href="https://archidep.example.com/2027/course/104-ssh/">SSH</a></p>),
               absolute_base_url: "https://archidep.example.com"
             ) ==
               {~s(<p><a href="https://archidep.example.com/2027/course/104-ssh/">SSH</a></p>),
                []}
    end

    test "leaves a link to an address that is not a site where it is" do
      assert run(~s(<p>Write to <a href="mailto:contact@archidep.ch">us</a>.</p>)) ==
               {~s(<p>Write to <a href="mailto:contact@archidep.ch">us</a>.</p>), []}
    end

    test "leaves an anchor that already says how it opens where it is" do
      assert run(~s(<p><a href="https://man7.org/" target="_self">the manual</a></p>)) ==
               {~s(<p><a href="https://man7.org/" target="_self">the manual</a></p>), []}
    end

    test "leaves an anchor that already says what it is to the page where it is" do
      assert run(~s(<p><a href="https://man7.org/" rel="nofollow">the manual</a></p>)) ==
               {~s(<p><a href="https://man7.org/" rel="nofollow">the manual</a></p>), []}
    end

    test "leaves an anchor pointing nowhere where it is" do
      assert run(~s(<p><a name="top"></a>The top of the page.</p>)) ==
               {~s(<p><a name="top"></a>The top of the page.</p>), []}
    end

    test "leaves the markup of the page alone" do
      assert run(
               ~s(<pre class="lumis"><code>&lt;a href="https://x.example.com/"&gt;</code></pre>)
             ) ==
               {~s(<pre class="lumis"><code>&lt;a href="https://x.example.com/"&gt;</code></pre>),
                []}
    end

    test "opens the links of a page that has none" do
      assert run("<p>Nothing to follow here.</p>") == {"<p>Nothing to follow here.</p>", []}
    end
  end

  defp run(html, url_context \\ []) do
    ExternalLinks.run(
      html,
      CourseSiteFactory.build(:render_context,
        source_path: "_course/104-ssh/subject.md",
        page: {:document, DocumentRef.new(104, "ssh", :subject)},
        urls:
          CourseSiteFactory.build(
            :url_context,
            Keyword.merge([version: "2027", base_path: ""], url_context)
          )
      )
    )
  end
end
