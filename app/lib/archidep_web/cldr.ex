defmodule ArchiDepWeb.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.Message],
    gettext: ArchiDepWeb.Gettext
end
