defmodule ArchiDep.CourseSite.Renderer.EmojiImagesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.EmojiImages
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.Emoji
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "chapters/406-unix-processes/subject.md"

  describe "run/2" do
    test "draws the shortcode a page opens a heading with" do
      assert run(~s(<h2 id="create-your-server">:exclamation: Create your server</h2>)) ==
               {~s(<h2 id="create-your-server">#{img("exclamation")} Create your server</h2>), []}
    end

    test "draws a shortcode standing after a space" do
      assert run("<p>That is all :tada:</p>") ==
               {"<p>That is all #{img("tada")}</p>", []}
    end

    test "draws the shortcode a block tag writes around its own body" do
      assert run(~s(<div class="title">:books:<span>More information</span></div>)) ==
               {~s(<div class="title">#{img("books")}<span>More information</span></div>), []}
    end

    test "draws an emoji a page writes as the character itself" do
      assert run("<p>Sadly... 😭</p>") == {"<p>Sadly... #{img("sob")}</p>", []}
    end

    test "draws an emoji written with another one inside it as the one it is" do
      assert run("<p>Stop telling me more 😵‍💫</p>") ==
               {"<p>Stop telling me more #{img("face_with_spiral_eyes")}</p>", []}
    end

    test "leaves the shortcodes a page shows as code alone" do
      assert run("<pre><code>jde:x:1004:1004::/home/jde:/bin/bash</code></pre>") ==
               {"<pre><code>jde:x:1004:1004::/home/jde:/bin/bash</code></pre>", []}
    end

    test "leaves a shortcode written in a code span alone" do
      assert run("<p>Write <code>:books:</code> for a reading list.</p>") ==
               {"<p>Write <code>:books:</code> for a reading list.</p>", []}
    end

    test "leaves the words a page writes between colons alone" do
      assert run("<p>Meeting at 10:30: what to bring.</p>") ==
               {"<p>Meeting at 10:30: what to bring.</p>", []}
    end

    test "leaves a shortcode naming no emoji of the site alone" do
      assert run("<p>The :unicorn: of deployment.</p>") ==
               {"<p>The :unicorn: of deployment.</p>", []}
    end

    test "leaves the markup of the page alone" do
      assert run(~s(<img class="chapter" src="tada.png" alt="A :tada: of a diagram" />)) ==
               {~s(<img class="chapter" src="tada.png" alt="A :tada: of a diagram" />), []}
    end

    test "reports an emoji that is not one of the site's, once for the page" do
      assert run("<p>Roll on 🛼 and on 🛼 again</p>") ==
               {"<p>Roll on 🛼 and on 🛼 again</p>",
                [RenderError.new({:unregistered_emoji, "🛼"}, @source_path)]}
    end

    test "reports the emoji whose file the build has no URL for, once for the page" do
      assert run("<p>:tada: :tada: :books:</p>", assets: AssetManifest.new(%{})) ==
               {"<p>:tada: :tada: :books:</p>",
                [
                  RenderError.new(
                    {:url, {:unknown_asset, "/assets/emoji/1f389.svg"}},
                    @source_path
                  ),
                  RenderError.new(
                    {:url, {:unknown_asset, "/assets/emoji/1f4da.svg"}},
                    @source_path
                  )
                ]}
    end

    test "draws the emoji of a page that writes none" do
      assert run("<p>Nothing to see here.</p>") == {"<p>Nothing to see here.</p>", []}
    end
  end

  describe "draw/3 over the Markdown of a deck" do
    test "draws a shortcode a deck writes right after the markup it sizes it with" do
      assert draw(~s(- Carelessness <div class="emoji-container">:coffee:</div>\n)) ==
               {~s(- Carelessness <div class="emoji-container">#{img("coffee")}</div>\n), []}
    end

    test "draws an emoji a deck writes as the character itself" do
      assert draw("> 🛠️ Try it yourself\n") ==
               {"> #{img("hammer_and_wrench")} Try it yourself\n", []}
    end

    test "leaves the shortcode-shaped words of a fenced code block alone" do
      assert draw("```bash\nNot After : Jan 15 14:28:11 2020 GMT\n```\n") ==
               {"```bash\nNot After : Jan 15 14:28:11 2020 GMT\n```\n", []}
    end

    test "leaves the shortcode-shaped words written between backticks alone" do
      assert draw("The address `0123:4567:89ab:cdef::1` is local.\n") ==
               {"The address `0123:4567:89ab:cdef::1` is local.\n", []}
    end

    test "leaves the Markdown of a deck that writes no emoji alone" do
      assert draw("# Slide\n\nSee [Ada](https://example.com/ada).\n") ==
               {"# Slide\n\nSee [Ada](https://example.com/ada).\n", []}
    end

    test "reports an emoji of a deck that is not one of the site's" do
      assert draw("# 🛼 Rolling\n") ==
               {"# 🛼 Rolling\n", [RenderError.new({:unregistered_emoji, "🛼"}, @source_path)]}
    end
  end

  defp img(name) do
    emoji = Emoji.fetch!(name)
    Emoji.img(emoji, "/2027#{Emoji.asset_path(emoji)}")
  end

  defp run(html, url_context \\ []), do: EmojiImages.run(html, context(url_context))

  defp draw(markdown, url_context \\ []),
    do: EmojiImages.draw(markdown, :markdown, context(url_context))

  defp context(url_context) do
    CourseSiteFactory.build(:render_context,
      source_path: @source_path,
      page: {:document, DocumentRef.new(406, "unix-processes", :subject)},
      urls:
        CourseSiteFactory.build(
          :url_context,
          Keyword.merge([version: "2027", base_path: ""], url_context)
        )
    )
  end
end
