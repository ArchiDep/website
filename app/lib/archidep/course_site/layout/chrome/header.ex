defmodule ArchiDep.CourseSite.Layout.Chrome.Header do
  @moduledoc """
  The bar across the top of every page: the way into the navigation on a narrow
  screen, the way home, and the ways in and out of an account.

  ## What starts hidden

  The search button, the login button and the account menu are written hidden
  and revealed by `course/src/assets/course.ts` once it knows whether there is
  a session. That is not a trick: the pages are static files, so the server that
  serves them cannot know who is reading, and a page that guessed would show a
  "Log in" button to somebody already logged in for as long as the script takes
  to load. Starting hidden makes the page say nothing until it knows.

  ## What is printed

  A printed page is read away from the site it came from, so it carries what the
  screen does not need: which edition this is, and which build. Everything that
  is a way of getting somewhere else is dropped from print instead, being of no
  use on paper.
  """

  use Phoenix.Component

  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.SiteInfo
  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  # Where the application is, which is not where the course is: the dashboard
  # answers at the root of the origin whatever mount point or edition prefix the
  # course was published under, so these are not references
  # `ArchiDep.CourseSite.Urls` has anything to say about. They are only ever
  # written into a build that is the live site
  # (`ArchiDep.CourseSite.Layout.Chrome.Policy`).
  @login_path "/auth/switch-edu-id/configure?to=%2F"
  @profile_path "/profile"

  attr :links, :map, required: true, doc: "the URLs of the chrome, already resolved"
  attr :policy, Policy, required: true, doc: "what of the application this build carries"
  attr :site, SiteInfo, required: true, doc: "what the build says about itself"

  @doc """
  The bar across the top of a page.
  """
  @spec header(map()) :: Rendered.t()
  def header(assigns) do
    ~H"""
    <header class="navbar bg-base-300 screen:shadow-sm w-full">
      <div class="navbar-start">
        <label for="sidebar" class="lg:hidden print:hidden btn btn-square btn-ghost">
          <Heroicons.bars_3 class="size-5" />
        </label>
        <a class="btn btn-ghost text-xl print:text-3xl print:pl-0" href={@links[:home]}>
          <div class="flex items-center gap-x-2">
            <div class="avatar">
              <div class="w-10">
                <img src={@links[:favicon_192]} alt="ArchiDep logo" />
              </div>
            </div>
            <h1 class="print:hidden">ArchiDep</h1>
            <h1 class="hidden print:block">Architecture &amp; Deployment</h1>
          </div>
        </a>
      </div>

      <div class="navbar-end flex gap-2 print:hidden">
        <button
          type="button"
          id="search-button"
          class="hidden btn btn-ghost max-sm:btn-circle hover:bg-neutral"
        >
          <Heroicons.magnifying_glass class="size-4 sm:size-6" />
          <kbd class="kbd kbd-xs sm:kbd-sm macos hidden">⌘K</kbd>
          <kbd class="kbd kbd-xs sm:kbd-sm hidden sm:inline">Ctrl K</kbd>
        </button>
        <a
          :if={@policy.account?}
          href={login_path()}
          id="login-button"
          class="hidden btn btn-ghost p-2"
        >
          <Heroicons.arrow_right_end_on_rectangle class="size-4 sm:size-6" />
          <span class="sr-only">Log in</span>
        </a>
        <div :if={@policy.account?} id="navbar-profile" class="hidden dropdown dropdown-end">
          <button type="button" class="btn btn-ghost btn-circle hover:bg-neutral">
            <div class="user hidden w-6 sm:w-8 rounded-full">
              <Heroicons.user_circle class="w-full" />
            </div>
            <div class="impersonator hidden w-6 sm:w-8 rounded-full">
              <Heroicons.eye class="w-full" />
            </div>
          </button>
          <ul class="menu menu-sm dropdown-content bg-base-300 rounded-box z-1 mt-3 w-52 p-2 shadow">
            <li>
              <a href={profile_path()} class="flex items-center gap-1">
                <Heroicons.user class="size-3.5" />
                <span>Profile</span>
              </a>
            </li>
            <li>
              <button type="button" id="logout-button" class="flex items-center gap-1" disabled>
                <Heroicons.arrow_right_start_on_rectangle class="size-3.5" />
                <span>Log out</span>
              </button>
            </li>
          </ul>
        </div>
      </div>
    </header>

    <div class="hidden print:block w-full">
      <ul class="list-none m-0 p-0 flex flex-wrap gap-2 text-xs text-base-content/50">
        <li>{@site.years}</li>
        <li>
          v{@site.version}
          <span :if={@links[:branch]}>
            on branch <a href={@links[:branch]}>{@site.git_branch}</a>
          </span>
        </li>
        <li :if={@links[:source]}>
          <a href={@links[:source]}>Rev: {@site.git_revision}</a>
        </li>
      </ul>
    </div>
    """
  end

  defp login_path, do: @login_path
  defp profile_path, do: @profile_path
end
