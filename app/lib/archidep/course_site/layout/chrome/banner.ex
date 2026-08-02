defmodule ArchiDep.CourseSite.Layout.Chrome.Banner do
  @moduledoc """
  What a build that is not the current site says at the top of every page: that
  it is not the thing the reader is probably after, and where that thing is.

  Two builds say it, for opposite reasons. The **backup copy** on GitHub Pages
  is a mirror of the edition being taught, so what it offers is the very same
  page on the live site — a reader who ended up here because the application was
  down loses nothing by going back once it is up. An **archived edition** is a
  past year kept at its own URLs, so what it offers is whatever supersedes this
  page in the current edition, which only the site being linked to can work out:
  the correspondence changes as the course is reworked, so the archive links to
  a route that resolves it rather than to a page named when the archive was
  frozen. That is what lets an archive stay frozen bytes.

  The live site draws neither, and a build is never both — see
  `ArchiDep.CourseSite.Urls.UrlContext` `mode`, which the presence of an edition
  prefix says nothing about: the current edition is served under one too.

  ## Written twice, because it is read in two places

  A page of the site has room for the whole statement and shows it as a bar
  under the header. A deck has no header, no navigation and nothing else that
  leads away from it, because it is shown on a projector — so it says as much of
  the same thing as fits in the corner where it already names the course and the
  build: a badge, and where it leads in the tooltip. Both are drawn from the
  same wording, which is why they are one module.

  Neither is printed. A printed page is read away from the site it came from, so
  a link to another site is of no use on it, and what a printed page carries
  instead of this is its edition, in the block the header prints.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  @kinds [:backup, :archive]

  attr :kind, :atom,
    required: true,
    values: @kinds,
    doc: "which kind of copy of the site this build is"

  attr :url, :string,
    required: true,
    doc: "where the reader is being sent: the live site, or whatever supersedes this page"

  attr :years, :string, required: true, doc: "the academic year this build holds"

  @doc """
  The bar a page of the site carries under its header.
  """
  @spec banner(map()) :: Rendered.t()
  def banner(assigns) do
    ~H"""
    <div
      role="alert"
      class="alert alert-warning alert-soft rounded-none flex flex-wrap justify-center text-center gap-x-2 print:hidden"
    >
      <span>{statement(@kind, @years)}</span>
      <a href={@url} class="link font-semibold transition-colors hover:text-base-content">
        {call_to_action(@kind)}
      </a>
    </div>
    """
  end

  attr :kind, :atom, required: true, values: @kinds, doc: "which kind of copy of the site this is"
  attr :url, :string, required: true, doc: "where the reader is being sent"

  @doc """
  The same thing as a deck has room for: a badge in the corner, saying which
  copy of the site this is, and where it leads in the tooltip. The edition is
  not named here, the corner naming it already.
  """
  @spec corner(map()) :: Rendered.t()
  def corner(assigns) do
    ~H"""
    <a href={@url} class="tooltip print:hidden" data-tip={tooltip(@kind)}>
      <span class="badge badge-warning badge-sm">{label(@kind)}</span>
    </a>
    """
  end

  defp statement(:backup, _years), do: "You are reading the backup copy of the ArchiDep website."
  defp statement(:archive, years), do: "This is the archived #{years} edition of the course."

  defp call_to_action(:backup), do: "Go to the live site."
  defp call_to_action(:archive), do: "Go to the current version of this page."

  # What the badge offers, which is the call to action and not the statement
  # before it: a tooltip is anchored on the badge and centred over it, so
  # anything longer is cut off by the edge of the slide. The archive's is
  # shorter still for the same reason — the page it stands for is the deck the
  # badge is drawn on, so it does not have to be named.
  defp tooltip(:backup), do: call_to_action(:backup)
  defp tooltip(:archive), do: "Go to the current version."

  defp label(:backup), do: "Backup copy"
  defp label(:archive), do: "Archived edition"
end
