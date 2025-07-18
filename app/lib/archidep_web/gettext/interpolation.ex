defmodule ArchiDepWeb.Gettext.Interpolation do
  @moduledoc """
  Custom translation interpolation module, using Cldr for advanced message
  formatting using ICU message format syntax (see
  https://unicode-org.github.io/icu/userguide/format_parse/messages/).
  """

  use Cldr.Gettext.Interpolation, cldr_backend: ArchiDepWeb.Cldr
end
