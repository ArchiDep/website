defmodule ArchiDep.CourseSite.Layout.Chrome.Home do
  @moduledoc """
  What the home page shows above what it says: the course's name, who teaches
  it, and a welcome.

  It replaces the title every other page draws, which is why the home page is
  the one page whose opening is a component rather than a heading: the course's
  name is a picture, a title, an institution and a set of badges, and none of
  that comes from the document's front matter.

  The badges saying whether the site is up and whether it last built are the
  only part of this that is not true of every build, which is why they ask [the
  policy](`ArchiDep.CourseSite.Layout.Chrome.Policy`). The licence badge stays:
  the course is MIT-licensed wherever it is read.

  The three cards showing what was taught last time, what is due next and what
  comes after are **not** here yet; they are the one reader of the progress
  source that still has no Elixir consumer.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered

  # What the chrome writes is a file of a build rather than something a
  # developer is reading in a browser, so it carries neither the comments nor
  # the attributes saying where a component was called from.
  @debug_heex_annotations false
  @debug_attributes false

  @heig_url "https://heig-vd.ch"
  @media_engineering_url "https://heig-vd.ch/formation/bachelor/ingenierie-des-medias/"

  @status_url "https://status.archidep.ch"
  @status_badge_url "https://status.archidep.ch/badge/_/status?labelColor=&color=&style=flat&label=status"

  @build_url "https://github.com/ArchiDep/website/actions/workflows/build.yml"
  @build_badge_url "https://github.com/ArchiDep/website/actions/workflows/build.yml/badge.svg"

  @licence_url "https://opensource.org/licenses/MIT"
  @licence_badge_url "https://img.shields.io/static/v1?label=license&message=MIT&color=informational"

  attr :links, :map, required: true, doc: "the URLs of the chrome, already resolved"
  attr :badges?, :boolean, required: true, doc: "whether this build reports on the live site"

  @doc """
  The course's name, in place of a title.
  """
  @spec title(map()) :: Rendered.t()
  def title(assigns) do
    ~H"""
    <div class="flex flex-wrap xs:flex-nowrap items-center gap-4">
      <div class="flex items-center gap-4">
        <img src={@links[:logo]} alt="ArchiDep logo" class="!m-0 w-40" />
      </div>
      <div>
        <h1 class="text-2xl md:text-2xl lg:text-3xl xl:text-3xl 2xl:text-5xl !mb-0 dark:text-white print:hidden">
          Architecture &amp; Deployment
        </h1>
        <div class="flex flex-wrap 2xl:flex-nowrap items-center gap-x-4 gap-y-2">
          <span class="flex items-center gap-2">
            <a href={heig_url()} target="_blank" rel="noopener noreferrer">
              <img src={@links[:heig_logo]} alt="HEIG-VD logo" class="!m-0 w-8" />
            </a>
            <small class="text-xl font-title whitespace-normal sm:whitespace-nowrap">
              A
              <a
                href={media_engineering_url()}
                class="link hover:text-accent"
                target="_blank"
                rel="noopener noreferrer"
              >
                Media Engineering
              </a>
              Course
            </small>
          </span>

          <ul class="not-prose flex flex-wrap md:flex-nowrap items-center gap-2">
            <li :if={@badges?} class="print:hidden">
              <a href={status_url()}>
                <img class="!m-0" src={status_badge_url()} alt="Status" />
              </a>
            </li>
            <li :if={@badges?} class="print:hidden">
              <a href={build_url()}>
                <img class="!m-0" src={build_badge_url()} alt="Build" />
              </a>
            </li>
            <li>
              <a href={licence_url()}>
                <img class="!m-0" src={licence_badge_url()} alt="MIT License" />
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  The greeting above the home page's own text.
  """
  @spec welcome(map()) :: Rendered.t()
  def welcome(assigns) do
    ~H"""
    <div class="not-prose alert alert-success alert-soft my-4 print:hidden" role="alert">
      <Heroicons.information_circle class="size-6 stroke-success shrink-0" />
      <span>Welcome to the Architecture &amp; Deployment course!</span>
    </div>
    """
  end

  defp heig_url, do: @heig_url
  defp media_engineering_url, do: @media_engineering_url
  defp status_url, do: @status_url
  defp status_badge_url, do: @status_badge_url
  defp build_url, do: @build_url
  defp build_badge_url, do: @build_badge_url
  defp licence_url, do: @licence_url
  defp licence_badge_url, do: @licence_badge_url
end
