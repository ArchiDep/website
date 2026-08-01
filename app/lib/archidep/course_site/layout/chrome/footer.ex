defmodule ArchiDep.CourseSite.Layout.Chrome.Footer do
  @moduledoc """
  What sits at the bottom of the navigation: who the course belongs to, and
  which build of it this is.

  It is drawn inside the sidebar rather than under the page because the page
  scrolls and the navigation does not — the footer is a property of the site,
  not of what is being read.

  The version is shown plainly and the commit only when hovered, because the
  version answers "which release is this" and the commit answers "which one
  exactly", which is a question far fewer readers are asking. A checkout that
  can name neither its branch nor its revision shows neither rather than half of
  one, since `main@` and `@abc1234` both read as something missing.

  The one thing here that is not true of every build is the badge saying whether
  the site is up, which is why it asks [the
  policy](`ArchiDep.CourseSite.Layout.Chrome.Policy`) rather than being drawn
  unconditionally.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Icons
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.SiteInfo
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # Enough of a commit to recognise it by, which is all a tooltip has room for.
  @revision_length 7

  # Whether the site is up, drawn by the service that watches it. What it
  # reports on is the live site, which is why only the live site shows it: an
  # archived edition is not watched at all, and the backup copy is read
  # precisely when the site the badge reports on is down, so a green dot there
  # would contradict the reason somebody is looking at it.
  @status_url "https://status.archidep.ch"
  @status_badge_url "https://status.archidep.ch/badge/_/dot"

  @heig_url "https://heig-vd.ch/"

  attr :links, :map, required: true, doc: "the URLs of the chrome, already resolved"
  attr :policy, Policy, required: true, doc: "what of the application this build carries"
  attr :version, :string, required: true, doc: "the release this build was made from"

  attr :commit, :string,
    default: nil,
    doc: "the commit this build was made from, when the checkout could name one"

  @doc """
  The foot of the navigation.
  """
  @spec footer(map()) :: Rendered.t()
  def footer(assigns) do
    ~H"""
    <footer class="p-4 absolute bottom-0 left-0 right-0 border-t border-black/10 dark:border-white/10">
      <div class="flex justify-between items-center gap-2">
        <p class="flex items-center gap-2">
          <a href={heig_url()} target="_blank" rel="noopener noreferrer">
            <img src={@links[:heig_logo]} alt="HEIG-VD logo" class="!m-0 w-8" />
          </a>
          <a :if={@policy.badges?} href={status_url()} target="_blank" rel="noopener noreferrer">
            <img src={status_badge_url()} alt="Status" />
          </a>
          <a href={@links[:repository]} target="_blank" rel="noopener noreferrer">
            <Icons.github class="size-4" />
          </a>
        </p>
        <p class="flex items-center gap-x-1 text-xs">
          <a href={@links[:home]} class="hover:text-accent flex items-center gap-1.5">
            <span class="avatar -mt-1">
              <span class="w-5">
                <img src={@links[:coffee_logo]} alt="ArchiDep logo" />
              </span>
            </span>
            <span class="font-title">ArchiDep</span>
          </a>
          <span :if={@commit} class="tooltip tooltip-left">
            <span class="tooltip-content">{@commit}</span>
            <span class="font-title">{@version}</span>
          </span>
          <span :if={@commit == nil} class="font-title">{@version}</span>
        </p>
      </div>
    </footer>
    """
  end

  @doc """
  The commit a build was made from, short enough to fit in a tooltip, or nothing
  when the checkout could name no commit.
  """
  @spec commit(SiteInfo.t()) :: String.t() | nil
  def commit(%SiteInfo{git_branch: nil}), do: nil
  def commit(%SiteInfo{git_revision: nil}), do: nil

  def commit(%SiteInfo{git_branch: branch, git_revision: revision}),
    do: "#{branch}@#{String.slice(revision, 0, @revision_length)}"

  defp heig_url, do: @heig_url
  defp status_url, do: @status_url
  defp status_badge_url, do: @status_badge_url
end
