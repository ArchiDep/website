defmodule ArchiDep.CourseSite.Layout.Chrome.TocTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.Chrome.Toc
  alias ArchiDep.CourseSite.Renderer.Toc.Entry

  describe "toc/1" do
    test "lists a page's headings, each linking to itself" do
      assert render([entry("what", 2, "What"), entry("why", 2, "Why")]) ==
               expected([
                 ~s(<li class="toc-entry toc-h2">\n    <a href="#what">What</a>\n    \n  </li>),
                 ~s(<li class="toc-entry toc-h2">\n    <a href="#why">Why</a>\n    \n  </li>)
               ])
    end

    test "sizes an entry by how deep its heading was written, not by how deep it sits" do
      assert render([entry("what", 3, "What")]) ==
               expected([
                 ~s(<li class="toc-entry toc-h3">\n    <a href="#what">What</a>\n    \n  </li>)
               ])
    end

    test "nests the headings written under a heading" do
      nested = entry("what", 2, "What", [entry("how", 3, "How")])

      assert render([nested]) ==
               expected([
                 ~s(<li class="toc-entry toc-h2">\n    <a href="#what">What</a>\n    ) <>
                   ~s(<ul class="section-nav">\n  <li class="toc-entry toc-h3">\n    ) <>
                   ~s(<a href="#how">How</a>\n    \n  </li>\n</ul>\n  </li>)
               ])
    end

    test "keeps the markup a heading was written with rather than what it reads as" do
      label = ~s(<img class="emoji" src="/x.svg" alt="❗" /> <code>ls</code>)

      assert render([entry("ls", 2, label)]) ==
               expected([
                 ~s(<li class="toc-entry toc-h2">\n    <a href="#ls">#{label}</a>\n    \n  </li>)
               ])
    end

    test "draws nothing at all for a page with no headings" do
      assert render([]) == ~s(<ul class="section-nav">\n  \n</ul>)
    end
  end

  defp render(entries), do: %{entries: entries} |> Toc.toc() |> Html.render()

  defp entry(id, level, label, entries \\ []),
    do: %Entry{id: id, level: level, label_html: label, entries: entries}

  defp expected(items), do: ~s(<ul class="section-nav">\n  #{Enum.join(items, "")}\n</ul>)
end
