defmodule ArchiDep.CourseSite.Layout.Chrome.Policy do
  @moduledoc """
  Which parts of the site's chrome a build carries.

  Most of what the chrome draws is true of every build: the course is the course
  wherever it is served from. A few pieces are not. Some point at the running
  application — signing in, the account menu, the switch between the course and
  the dashboard, the badges saying whether the site is up — and a build that is
  not the live site either cannot reach those or should not offer them, so it
  leaves them out. One says where the course has got to, which a finished
  edition has nothing to say about.

  ## One list, not a flag per template

  What makes this a value rather than a condition written where each piece is
  drawn is that "dashboard-free" is otherwise a claim spread over five
  templates, where nobody can read off what it covers. Here it is a list with a
  name for each entry, and a layout asks it instead of asking what kind of build
  this is.

  ## Derived from the mode, never from the host

  Whether a build carries the dynamic chrome follows from
  `ArchiDep.CourseSite.Urls.UrlContext` `mode` alone. A past edition has no
  dashboard whichever host serves it, and the backup copy exists precisely for
  when the application is unreachable — so a Dashboard link there points at the
  thing that is down. Keying any of this off the host or the mount point would
  make a build that contradicts itself representable.

  The entries are not keyed alike, which is the reason each is named separately
  rather than being read off one boolean: they answer different questions about
  a build, and the answers differ.

  ## A finished edition has nothing due next

  The home page's cards — what was covered last time, what is due next, what the
  next session covers — are the one entry that is not about the running
  application, and the one an archive alone leaves out, whatever its progress
  source reports. A past edition's snapshot has every chapter done, which would
  draw a "Previously" listing the whole course and drop the other two by
  emptiness: plausible-looking output nobody decided on. What is due next is a
  statement about a course in progress, and a finished year has no such thing to
  say. The backup copy keeps the cards, because it tracks the live progress
  source, so what is due next is still true there.
  """

  alias ArchiDep.CourseSite.Urls.UrlContext

  @enforce_keys [:app_navigation?, :account?, :badges?, :progress_cards?]
  defstruct [:app_navigation?, :account?, :badges?, :progress_cards?]

  @typedoc """
  What the chrome of a build draws beyond the course itself: the menu switching
  between the course and the dashboard, the ways in and out of an account, the
  badges reporting on the site itself, and the home page's cards saying where
  the course has got to.
  """
  @type t :: %__MODULE__{
          app_navigation?: boolean(),
          account?: boolean(),
          badges?: boolean(),
          progress_cards?: boolean()
        }

  @doc """
  Work out what the chrome of a build carries from where it is published.

      iex> Policy.of(UrlContext.new(mode: :live, build_id: "build"))
      %Policy{app_navigation?: true, account?: true, badges?: true, progress_cards?: true}

      iex> Policy.of(UrlContext.new(mode: :backup, build_id: "build"))
      %Policy{app_navigation?: false, account?: false, badges?: false, progress_cards?: true}

      iex> Policy.of(UrlContext.new(mode: :archive, build_id: "build", version: "2025"))
      %Policy{app_navigation?: false, account?: false, badges?: false, progress_cards?: false}
  """
  @spec of(UrlContext.t()) :: t()
  def of(%UrlContext{mode: mode}) do
    live? = mode == :live

    %__MODULE__{
      app_navigation?: live?,
      account?: live?,
      badges?: live?,
      progress_cards?: mode != :archive
    }
  end
end
