defmodule ArchiDepWeb.Gettext do
  use Gettext.Backend,
    otp_app: :archidep,
    interpolation: ArchiDepWeb.Gettext.Interpolation
end
