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
  a student to for their virtual server, the cheatsheet on system administration
  — and a dozen headings *within* those pages. Each of them is an attribute
  resolved **here**, at compile time, rather than a lookup at each call site. So
  a chapter renamed or a heading reworded in the course is a compilation failure
  naming the reference, not a dead link discovered by a reader.

  A heading costs more to name than a page does: its identifier is slugged while
  its page is rendered, so `ArchiDep.CourseSite.Build.headings!/2` renders the
  two pages named below in order to answer for them. Only those two, and with
  the renderer's passes dropped, which is what keeps a compilation from needing
  a build's asset manifests.

  Every one of them stores an identity rather than a URL, which the application
  resolves through `ArchiDep.CourseSite.Urls` when it renders a page. That is
  what keeps the mount point and the edition prefix out of a compiled module.

  ## When it is compiled again

  Two mechanisms, covering two different questions, because neither covers the
  other's case:

  - **What a file says** — every Markdown source, the declarations, every
    recorded session and every partial a document may include are
    `@external_resource`s, so Mix compares each one's content digest and
    recompiles when one is edited or deleted.
  - **What the directory holds** — `__mix_recompile__?/0` compares
    `ArchiDep.CourseSite.Build.content_digest/1`, which is what catches a file
    being *added*. An `@external_resource` cannot: a file nobody has registered
    is a file Mix is not watching.

  Only the Markdown sources are registered, not the files beside them: their
  *names* are what this module depends on and the digest already covers those,
  where registering 49 MB of images would have Mix digest all of them on every
  compile. The digest covers the collections a build renders, so a **newly
  added** session of the course, and a partial nothing yet includes, are the
  changes neither mechanism notices.
  """

  alias ArchiDep.CourseSite.Build
  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.Headings
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
  @includes_dir Path.join(@course_dir, "_includes")
  @declarations_file Path.join(@course_dir, "_data/course.yml")

  @external_resource @declarations_file
  for file <- Build.content_files(@content_dir), String.ends_with?(file, ".md") do
    @external_resource Path.join(@content_dir, file)
  end

  for file <- Build.progress_files(@content_dir) do
    @external_resource Path.join(@content_dir, file)
  end

  for file <- Build.include_files(@includes_dir) do
    @external_resource Path.join(@includes_dir, file)
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

  @run_virtual_server_page Chapter.page_ref(@run_virtual_server_exercise)
  @sysadmin_page @structure |> Structure.cheatsheet!("sysadmin") |> Cheatsheet.page_ref()

  @headings Build.headings!(@content_dir, @includes_dir, [
              @run_virtual_server_page,
              @sysadmin_page
            ])

  @create_your_server Headings.heading!(@headings, @run_virtual_server_page, "create-your-server")
  @configure_your_administrator_account Headings.heading!(
                                          @headings,
                                          @run_virtual_server_page,
                                          "configure-your-administrator-account"
                                        )
  @give_the_teacher_access Headings.heading!(
                             @headings,
                             @run_virtual_server_page,
                             "give-the-teacher-access-to-your-virtual-machine"
                           )
  @register_your_server_with_us Headings.heading!(
                                  @headings,
                                  @run_virtual_server_page,
                                  "register-your-azure-vm-with-us"
                                )
  @configure_basic_settings Headings.heading!(
                              @headings,
                              @run_virtual_server_page,
                              "configure-basic-settings"
                            )
  @change_the_hostname Headings.heading!(
                         @headings,
                         @run_virtual_server_page,
                         "change-the-hostname-of-your-virtual-machine"
                       )
  @add_swap_space Headings.heading!(
                    @headings,
                    @run_virtual_server_page,
                    "add-swap-space-to-your-virtual-server"
                  )
  @configure_open_ports Headings.heading!(
                          @headings,
                          @run_virtual_server_page,
                          "configure-open-ports"
                        )
  @forgot_to_open_ports Headings.heading!(
                          @headings,
                          @run_virtual_server_page,
                          "i-forgot-to-open-some-or-all-of-the-ports-in-the-firewall"
                        )
  @change_your_username Headings.heading!(
                          @headings,
                          @sysadmin_page,
                          "how-do-i-change-my-username-usermod"
                        )

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
  Where the exercise has a student create their server, which is where the
  dashboard sends them to find its address.
  """
  @spec create_your_server() :: HeadingRef.t()
  def create_your_server, do: @create_your_server

  @doc """
  Where the exercise has a student choose the username of their administrator
  account, which is the username the dashboard logs in with.
  """
  @spec configure_your_administrator_account() :: HeadingRef.t()
  def configure_your_administrator_account, do: @configure_your_administrator_account

  @doc """
  Where the exercise has a student authorize the course's SSH public key, which
  is what the dashboard connects with.
  """
  @spec give_the_teacher_access() :: HeadingRef.t()
  def give_the_teacher_access, do: @give_the_teacher_access

  @doc """
  Where the exercise has a student register their server's SSH host key
  fingerprints, which is what the dashboard checks a connection against.
  """
  @spec register_your_server_with_us() :: HeadingRef.t()
  def register_your_server_with_us, do: @register_your_server_with_us

  @doc """
  Where the exercise has a student choose the hardware and operating system of
  their server, which is one of the properties the dashboard expects.
  """
  @spec configure_basic_settings() :: HeadingRef.t()
  def configure_basic_settings, do: @configure_basic_settings

  @doc """
  Where the exercise has a student name their server, which is one of the
  properties the dashboard expects.
  """
  @spec change_the_hostname() :: HeadingRef.t()
  def change_the_hostname, do: @change_the_hostname

  @doc """
  Where the exercise has a student give their server swap space, which is one of
  the properties the dashboard expects.
  """
  @spec add_swap_space() :: HeadingRef.t()
  def add_swap_space, do: @add_swap_space

  @doc """
  Where the exercise has a student open the ports of their server, which is what
  the dashboard tries to reach.
  """
  @spec configure_open_ports() :: HeadingRef.t()
  def configure_open_ports, do: @configure_open_ports

  @doc """
  Where the exercise tells a student what to do about a port they did not open,
  which is what the dashboard offers when it cannot reach one.
  """
  @spec forgot_to_open_ports() :: HeadingRef.t()
  def forgot_to_open_ports, do: @forgot_to_open_ports

  @doc """
  Where the cheatsheet tells a student how to rename their Unix user account,
  which is what the dashboard offers when they change their username.
  """
  @spec change_your_username() :: HeadingRef.t()
  def change_your_username, do: @change_your_username

  @doc """
  Whether the content directory now holds different files than the ones this
  module was compiled from.
  """
  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @content_digest != Build.content_digest(@content_dir)
end
