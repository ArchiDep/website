defmodule ArchiDep.CourseSite.Material do
  @moduledoc """
  The course this application was built for, worked out from the Markdown while
  the application compiles.

  Everything else in `ArchiDep.CourseSite` is a function of its inputs. This
  module is the subsystem's one **edition-bound** value: one particular content
  directory, baked.

  It is compiled because a page the dashboard names that the course no longer
  holds has to fail the build rather than a reader's click, and because the
  structure of an edition does not change while the application runs — unlike
  `ArchiDep.CourseSite.Progress`, whose source is meant to move.

  It reads nothing itself. `ArchiDep.CourseSite.Build` stays the only module
  here that touches the filesystem; what happens at compile time is a call to
  it.

  ## What links into it

  The dashboard names a few pages of the course material — the exercise it sends
  a student to for their virtual server, the cheatsheet section on changing a
  username — and each of those is an attribute resolved **here**, at compile
  time, rather than a lookup at each of the twelve call sites. So a chapter
  renamed in the course is a compilation failure naming the reference, not a
  dead link discovered by a reader.

  Every one of them stores an identity rather than a URL, which the application
  resolves through `ArchiDep.CourseSite.Urls` when it renders a page. That is
  what keeps the mount point and the edition prefix out of a compiled module.

  ## When it is compiled again

  Two mechanisms, covering two different questions, because neither covers the
  other's case:

  - **What a file says** — every Markdown source, the declarations and every
    recorded session are `@external_resource`s, so Mix compares each one's
    content digest and recompiles when one is edited or deleted.
  - **What the directory holds** — `__mix_recompile__?/0` compares
    `ArchiDep.CourseSite.Build.content_digest/1`, which is what catches a file
    being *added*. An `@external_resource` cannot: a file nobody has registered
    is a file Mix is not watching.

  Only the Markdown sources are registered, not the files beside them: their
  *names* are what this module depends on and the digest already covers those,
  where registering 49 MB of images would have Mix digest all of them on every
  compile. The digest covers the collections a build renders, so a **newly
  added** session of the course is the one change neither mechanism notices.
  """

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section

  # Resolved against this file rather than through a configuration knob, so that
  # it can only ever mean the content directory of the repository the
  # application was compiled from.
  @course_dir Path.expand("../../../../course", __DIR__)
  @content_dir Path.join(@course_dir, "collections")
  @declarations_file Path.join(@course_dir, "_data/course.yml")

  @external_resource @declarations_file
  for file <- Build.content_files(@content_dir), String.ends_with?(file, ".md") do
    @external_resource Path.join(@content_dir, file)
  end

  for file <- Build.progress_files(@content_dir) do
    @external_resource Path.join(@content_dir, file)
  end

  @content_digest Build.content_digest(@content_dir)
  @structure Build.course!(@content_dir, @declarations_file)
  @progress Progress.new(Build.progress_entries!(@content_dir))

  # Projected while this module compiles rather than in a function body, so that
  # listing the course is not a map access on a literal of a few thousand words
  # per call.
  @sections @structure.sections
  @cheatsheets @structure.cheatsheets

  @run_virtual_server_exercise Structure.chapter!(@structure, 402, "run-virtual-server")
  @sysadmin_cheatsheet Structure.cheatsheet!(@structure, "sysadmin")

  @doc """
  What the course is: its sections, the chapters of each and its cheatsheets, in
  reading order.
  """
  @spec structure() :: Structure.t()
  def structure, do: @structure

  @doc """
  The sections of the course, in reading order.
  """
  @spec sections() :: [Section.t()]
  def sections, do: @sections

  @doc """
  The cheatsheets of the course, in the order the course declares them in.
  """
  @spec cheatsheets() :: [Cheatsheet.t()]
  def cheatsheets, do: @cheatsheets

  @doc """
  How far the course had got when this application was built.

  This one is an interim: it is compiled from the sessions recorded in the
  content directory, so the dashboard shows the same progress until it is built
  again.
  """
  @spec progress() :: Progress.t()
  def progress, do: @progress

  @doc """
  The exercise the dashboard sends a student to when they have no server yet.
  """
  @spec run_virtual_server_exercise() :: Chapter.t()
  def run_virtual_server_exercise, do: @run_virtual_server_exercise

  @doc """
  The cheatsheet the dashboard sends a student to for the commands of a system
  administrator.
  """
  @spec sysadmin_cheatsheet() :: Cheatsheet.t()
  def sysadmin_cheatsheet, do: @sysadmin_cheatsheet

  @doc """
  Whether the content directory now holds different files than the ones this
  module was compiled from.
  """
  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @content_digest != Build.content_digest(@content_dir)
end
