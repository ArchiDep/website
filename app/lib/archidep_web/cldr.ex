defmodule ArchiDepWeb.Cldr do
  @moduledoc """
  Cldr configuration, providing localization and internationalization support.
  """

  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.Message],
    gettext: ArchiDepWeb.Gettext
end
