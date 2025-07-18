defmodule ArchiDepWeb.Gettext do
  @moduledoc """
  Gettext configuration for translation support, with custom interpolation to
  use the ICU message format (see
  https://unicode-org.github.io/icu/userguide/format_parse/messages/).
  """

  use Gettext.Backend,
    otp_app: :archidep,
    interpolation: ArchiDepWeb.Gettext.Interpolation
end
