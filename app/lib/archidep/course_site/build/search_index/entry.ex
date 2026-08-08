defmodule ArchiDep.CourseSite.Build.SearchIndex.Entry do
  @moduledoc """
  One thing the search dialog can find.

  A page contributes several: itself, and one for each of its top-level
  headings, so that a search lands on the part of a page that answers it rather
  than on the page that happens to hold it.

  `id` is what the client's index refers to a result by, and it is the page's
  own path — with the heading's fragment on it, where there is one — rather than
  the URL beside it: the build's own coordinates carry neither the mount point
  nor the edition, so a page keeps the same identity in every copy of the site
  while `url` says where that copy serves it.

  `subtitle` is what a result is shown under. A page is shown under whatever it
  says of itself and a heading under the page it is on, which is why the two are
  filled from different places rather than one inheriting the other.

  `extra_text` is indexed and never displayed. It exists so that a page can be
  found by words it does not show — the home page is the one page in the course
  nobody searches for by name.
  """

  @enforce_keys [:id, :type, :url, :title, :subtitle]
  defstruct [:id, :type, :url, :title, :subtitle, text: "", extra_text: ""]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          url: String.t(),
          title: String.t(),
          subtitle: String.t(),
          text: String.t(),
          extra_text: String.t()
        }
end
