defmodule ArchiDep.CourseSite.Renderer.PageMetadataTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.Support.CourseSiteFactory

  @site_description "Media engineering architecture and deployment course"

  describe "of/2" do
    test "says what a page is called, what it is about and where it lives" do
      assert metadata_of(
               "Secure Shell (SSH)",
               "<p>Learn about the SSH cryptographic network protocol.</p>"
             ) ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: "Learn about the SSH cryptographic network protocol.",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "describes a page by its opening as it is read rather than as it is written" do
      assert metadata_of(
               "Secure Shell (SSH)",
               ~s(<h2 id="what">) <>
                 ~s(<img class="emoji" src="/2027/assets/emoji/1f4da.svg" alt="📚" />) <>
                 ~s( What you will learn</h2>\n<ul>\n<li>How to <em>connect</em>.</li>\n</ul>)
             ) ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: "What you will learn How to connect.",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "describes a page whose opening is written with entities by what they say" do
      assert metadata_of("Deployment", "<p>Learn about Q&amp;A and the &lt;head&gt;.</p>") ==
               %PageMetadata{
                 title: "Deployment · ArchiDep",
                 page_title: "Deployment",
                 description: "Learn about Q&A and the <head>.",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "cuts the description of a page whose opening is a whole section" do
      opening = Enum.map_join(1..250, " ", &"word#{&1}")
      cut = Enum.map_join(1..200, " ", &"word#{&1}")

      assert metadata_of("Secure Shell (SSH)", "<p>#{opening}</p>") ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: cut <> "…",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "describes a page with nothing to introduce it by what the site is about" do
      assert metadata_of("Secure Shell (SSH)", nil) ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: @site_description,
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "describes a page whose opening says nothing by what the site is about" do
      assert metadata_of("Secure Shell (SSH)", "<hr />") ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: @site_description,
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "calls a page with no title of its own by the site's name" do
      assert metadata_of(nil, "<p>An untitled page.</p>") ==
               %PageMetadata{
                 title: "ArchiDep",
                 page_title: nil,
                 description: "An untitled page.",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "calls a page titled after the site by that name once" do
      assert metadata_of("ArchiDep", "<p>The course itself.</p>") ==
               %PageMetadata{
                 title: "ArchiDep",
                 page_title: "ArchiDep",
                 description: "The course itself.",
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/"
               }
    end

    test "says nothing of where a page lives in a build that does not know the site" do
      assert metadata_of("Secure Shell (SSH)", "<p>An opening.</p>", live_site_url: nil) ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: "An opening.",
                 canonical_url: nil
               }
    end

    test "takes a slide deck to have no opening" do
      context =
        CourseSiteFactory.build(:render_context,
          page: {:document, DocumentRef.new(104, "ssh", :slides)},
          page_variables: %{"title" => "Secure Shell (SSH)"},
          urls:
            CourseSiteFactory.build(:url_context,
              mode: :live,
              base_path: "",
              version: "2027",
              live_site_url: "https://archidep.example.com"
            )
        )

      assert PageMetadata.of(context) ==
               %PageMetadata{
                 title: "Secure Shell (SSH) · ArchiDep",
                 page_title: "Secure Shell (SSH)",
                 description: @site_description,
                 canonical_url: "https://archidep.example.com/2027/course/104-ssh/slides/"
               }
    end
  end

  describe "to_html/1" do
    test "writes what a page says about itself as the tags a head carries" do
      metadata = %PageMetadata{
        title: "Secure Shell (SSH) · ArchiDep",
        page_title: "Secure Shell (SSH)",
        description: "Learn about the SSH cryptographic network protocol.",
        canonical_url: "https://archidep.ch/2027/course/104-ssh/"
      }

      assert PageMetadata.to_html(metadata) ==
               String.trim_trailing("""
               <title>Secure Shell (SSH) · ArchiDep</title>
               <meta name="description" content="Learn about the SSH cryptographic network protocol." />
               <link rel="canonical" href="https://archidep.ch/2027/course/104-ssh/" />
               <meta property="og:type" content="website" />
               <meta property="og:site_name" content="ArchiDep" />
               <meta property="og:locale" content="en_US" />
               <meta property="og:title" content="Secure Shell (SSH)" />
               <meta property="og:description" content="Learn about the SSH cryptographic network protocol." />
               <meta property="og:url" content="https://archidep.ch/2027/course/104-ssh/" />
               <meta name="twitter:card" content="summary" />
               """)
    end

    test "leaves out what the build has nothing to say" do
      metadata = %PageMetadata{
        title: "ArchiDep",
        page_title: nil,
        description: @site_description,
        canonical_url: nil
      }

      assert PageMetadata.to_html(metadata) ==
               String.trim_trailing("""
               <title>ArchiDep</title>
               <meta name="description" content="#{@site_description}" />
               <meta property="og:type" content="website" />
               <meta property="og:site_name" content="ArchiDep" />
               <meta property="og:locale" content="en_US" />
               <meta property="og:description" content="#{@site_description}" />
               <meta name="twitter:card" content="summary" />
               """)
    end

    test "writes what a page says of itself so that it says it" do
      metadata = %PageMetadata{
        title: ~s(Architecture & Deployment · ArchiDep),
        page_title: ~s(Architecture & Deployment),
        description: ~s(Deploy the "todolist" application <not> the other one.),
        canonical_url: "https://archidep.ch/"
      }

      assert PageMetadata.to_html(metadata) ==
               String.trim_trailing("""
               <title>Architecture &amp; Deployment · ArchiDep</title>
               <meta name="description" content="Deploy the &quot;todolist&quot; application &lt;not&gt; the other one." />
               <link rel="canonical" href="https://archidep.ch/" />
               <meta property="og:type" content="website" />
               <meta property="og:site_name" content="ArchiDep" />
               <meta property="og:locale" content="en_US" />
               <meta property="og:title" content="Architecture &amp; Deployment" />
               <meta property="og:description" content="Deploy the &quot;todolist&quot; application &lt;not&gt; the other one." />
               <meta property="og:url" content="https://archidep.ch/" />
               <meta name="twitter:card" content="summary" />
               """)
    end
  end

  defp metadata_of(title, excerpt_html, url_context \\ []) do
    context =
      CourseSiteFactory.build(:render_context,
        page: {:document, DocumentRef.new(104, "ssh", :subject)},
        page_variables: page_variables(title),
        urls:
          CourseSiteFactory.build(
            :url_context,
            Keyword.merge(
              [
                mode: :live,
                base_path: "",
                version: "2027",
                live_site_url: "https://archidep.example.com"
              ],
              url_context
            )
          )
      )

    PageMetadata.of(context, excerpt_html)
  end

  defp page_variables(nil), do: %{}
  defp page_variables(title), do: %{"title" => title}
end
