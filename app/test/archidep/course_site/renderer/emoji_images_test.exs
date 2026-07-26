defmodule ArchiDep.CourseSite.Renderer.EmojiImagesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.EmojiImages
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.Emoji
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "_course/406-unix-processes/subject.md"

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

  defp img(name) do
    emoji = Emoji.fetch!(name)
    Emoji.img(emoji, "/2027#{Emoji.asset_path(emoji)}")
  end

  defp run(html, url_context \\ []) do
    EmojiImages.run(
      html,
      CourseSiteFactory.build(:render_context,
        source_path: @source_path,
        page: {:document, DocumentRef.new(406, "unix-processes", :subject)},
        urls:
          CourseSiteFactory.build(
            :url_context,
            Keyword.merge([version: "2027", base_path: ""], url_context)
          )
      )
    )
  end
end
