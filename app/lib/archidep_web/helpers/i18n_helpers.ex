defmodule ArchiDepWeb.Helpers.I18nHelpers do
  @spec pluralize(non_neg_integer, String.t()) :: String.t()
  @spec pluralize(non_neg_integer, String.t(), String.t() | nil) :: String.t()
  def pluralize(count, singular, plural \\ nil)
  def pluralize(1, singular, _plural), do: singular
  def pluralize(_count, singular, plural), do: plural || "#{singular}s"
end
