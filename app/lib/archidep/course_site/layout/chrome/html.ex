defmodule ArchiDep.CourseSite.Layout.Chrome.Html do
  @moduledoc """
  How what a component drew becomes the string a build writes to a file.

  The site's chrome is markup, and markup is written in HEEx here as it is in
  the dashboard, so what a chrome component returns is a
  `Phoenix.LiveView.Rendered` — a tree of static parts and the values between
  them, meant to be sent down a socket in pieces. A build has no socket and no
  request: it has a file to write. So the tree is flattened once, here, and
  everything upstream deals in strings.

  Nothing about this needs an application to be running. A component is a
  function of its assigns and `Phoenix.HTML.Safe` knows how to write one out,
  which is what lets the chrome be HEEx without the subsystem gaining a
  dependency on a running endpoint.
  """

  alias Phoenix.HTML.Safe
  alias Phoenix.LiveView.Rendered

  @doc """
  Flatten what a component drew into the string it stands for.
  """
  @spec render(Rendered.t()) :: String.t()
  def render(%Rendered{} = rendered),
    do: rendered |> Safe.to_iodata() |> IO.iodata_to_binary()
end
