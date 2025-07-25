defmodule ArchiDepWeb.Components.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use ArchiDepWeb, :controller` and
  `use ArchiDepWeb, :live_view`.
  """
  use ArchiDepWeb, :html

  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Course.Material
  alias Phoenix.LiveView.JS

  embed_templates "layouts/*"
end
