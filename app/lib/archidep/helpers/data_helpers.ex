defmodule ArchiDep.Helpers.DataHelpers do
  def looks_like_an_email?(email) when is_binary(email),
    do: String.match?(email, ~r/\A.+@.+\..+\z/)
end
