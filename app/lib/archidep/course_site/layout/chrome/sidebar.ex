defmodule ArchiDep.CourseSite.Layout.Chrome.Sidebar do
  @moduledoc """
  The navigation beside every page: the whole course, section by section, with
  the cheatsheets after it.

  ## The folds are CSS, not a script

  A section folds through a hidden checkbox its own label toggles, and the
  chapters under it are shown by the `peer` of that checkbox. Nothing scripts
  it, which is why it works on a page served from a file with JavaScript turned
  off. The peer is numbered by the section's place in the list rather than named
  after it, so `theme/src/theme.css` can list the handful of numbers it must
  keep — a class Tailwind never sees written down is a class it never emits.

  A section the course has reached is folded open and its checkbox disabled: it
  is open because that is where the reader is, and it cannot be closed because
  closing it would hide the only part of the course that is currently being
  taught.

  ## The colours come from the theme, not from here

  How far the course has got with a chapter is written as `course-item-done` and
  the like rather than as the border classes that draw it. The dashboard's own
  copy of this menu says the same thing the same way, so the two cannot drift
  into looking different, and what a status *looks* like stays one decision made
  in one stylesheet.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.EntryTitle
  alias ArchiDep.CourseSite.Layout.Chrome.Footer
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias ArchiDep.CourseSite.Layout.Chrome.MenuSection
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # Where the application is, for the menu switching between the course and it.
  # See `ArchiDep.CourseSite.Layout.Chrome.Header` for why these are not
  # references the URL seam knows about.
  @dashboard_path "/app"
  @admin_path "/admin"

  attr :sections, :list, required: true, doc: "the course, as MenuSection values"
  attr :cheatsheets, :list, required: true, doc: "the cheatsheets, as MenuEntry values"
  attr :links, :map, required: true, doc: "the URLs of the chrome, already resolved"
  attr :policy, Policy, required: true, doc: "what of the application this build carries"
  attr :home?, :boolean, required: true, doc: "whether the page being drawn is the home page"
  attr :version, :string, required: true, doc: "the release this build was made from"
  attr :commit, :string, default: nil, doc: "the commit this build was made from, if any"

  @doc """
  The navigation of the course material.
  """
  @spec sidebar(map()) :: Rendered.t()
  def sidebar(assigns) do
    ~H"""
    <div class="w-80 max-w-full bg-base-200 text-base-content min-h-full pb-16">
      <div class="lg:hidden w-full flex justify-between items-center pl-6 pr-2 pt-4">
        <a href={@links[:home]} class="text-xl font-bold inline">
          <div class="flex items-center gap-x-2">
            <div class="avatar">
              <div class="w-10">
                <img src={@links[:favicon_192]} alt="ArchiDep logo" />
              </div>
            </div>
            <span class="font-title">ArchiDep</span>
          </div>
        </a>
        <label for="sidebar" class="btn btn-square btn-ghost">
          <Heroicons.x_mark class="size-5" />
        </label>
      </div>
      <div :if={@policy.app_navigation?} class="px-4">
        <ul class="menu menu-horizontal grid grid-cols-5 gap-2">
          <li>
            <a
              href={@links[:home]}
              class={[@home? && "bg-primary/50", "tooltip tooltip-bottom"]}
              data-tip="Course"
            >
              <Heroicons.home class="w-full" />
              <span class="sr-only">Course</span>
            </a>
          </li>
          <li>
            <a href={dashboard_path()} class="tooltip tooltip-bottom" data-tip="Dashboard">
              <Heroicons.cube class="w-full" />
              <span class="sr-only">Dashboard</span>
            </a>
          </li>
          <li>
            <a
              href={admin_path()}
              id="sidebar-admin-item"
              class="hidden tooltip tooltip-bottom"
              data-tip="Admin"
            >
              <Heroicons.fire class="text-error w-full" />
              <span class="sr-only">Admin</span>
            </a>
          </li>
        </ul>
      </div>
      <ul id="course-material-menu" class="w-full menu px-4 pt-0 pb-4">
        <%= for {section, index} <- Enum.with_index(@sections) do %>
          <li class={[
            "peer/section-#{index}",
            "group/section-#{index}",
            "course-section-#{section.status}"
          ]}>
            <label for={"section-#{section.slug}-toggle"} class="flex justify-between items-center">
              <span class="text-base-content/50 cursor-default">{section.title}</span>
              <span :if={not section.open?} class={"group-has-checked/section-#{index}:hidden"}>
                <Heroicons.chevron_down class="size-4 text-base-content/50" />
              </span>
              <span :if={not section.open?} class={"hidden group-has-checked/section-#{index}:inline"}>
                <Heroicons.chevron_up class="size-4 text-base-content/50" />
              </span>
              <input
                type="checkbox"
                id={"section-#{section.slug}-toggle"}
                class="hidden"
                checked={section.open? or current_section?(section)}
                disabled={section.open?}
              />
            </label>
          </li>
          <li
            :for={entry <- section.entries}
            class={[
              "group",
              "hidden peer-has-checked/section-#{index}:flex",
              status_class(entry),
              entry.current? && "course-item-current"
            ]}
          >
            <a
              href={entry.url}
              target={if entry.deck?, do: "_blank", else: "_self"}
              class="flex items-center gap-2"
            >
              <EntryTitle.entry_title entry={entry} />
              <span :if={entry.deck_emoji_html}>{Phoenix.HTML.raw(entry.deck_emoji_html)}</span>
              <Heroicons.arrow_top_right_on_square
                :if={entry.deck?}
                class="size-4 text-base-content/25 group-hover:text-base-content/75"
              />
            </a>
          </li>
        <% end %>
        <li>
          <span class="text-base-content/50 cursor-default">Cheatsheets</span>
        </li>
        <li :for={entry <- @cheatsheets} class={entry.current? && "course-item-current"}>
          <a href={entry.url} class="flex items-center gap-2">
            <EntryTitle.entry_title entry={entry} />
          </a>
        </li>
      </ul>

      <Footer.footer links={@links} policy={@policy} version={@version} commit={@commit} />
    </div>
    """
  end

  # A section holding the page being read starts open, so that a reader arriving
  # from a link can see where they are without opening anything.
  defp current_section?(%MenuSection{entries: entries}),
    do: Enum.any?(entries, & &1.current?)

  # A line the course's progression says nothing about is drawn plainly rather
  # than as one of its stages — see
  # `ArchiDep.CourseSite.Layout.Chrome.MenuEntry`.
  defp status_class(%MenuEntry{status: nil}), do: nil
  defp status_class(%MenuEntry{status: status}), do: "course-item-#{status}"

  defp dashboard_path, do: @dashboard_path
  defp admin_path, do: @admin_path
end
