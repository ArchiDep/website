defmodule ArchiDepWeb.Course.LatestHTML do
  @moduledoc """
  The one page `ArchiDepWeb.Course.LatestController` renders, for the reader it
  has nowhere to send.

  Its templates sit in a directory of their own because the course's other web
  modules are LiveComponents sharing this one.
  """

  use ArchiDepWeb, :html

  embed_templates("latest/*")
end
