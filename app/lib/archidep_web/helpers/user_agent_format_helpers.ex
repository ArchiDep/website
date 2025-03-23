defmodule ArchiDepWeb.Helpers.UserAgentFormatHelpers do
  @spec format_user_agent(term) :: String.t()

  def format_user_agent(user_agent) when is_binary(user_agent),
    do: user_agent |> UAInspector.parse() |> format_parsed_user_agent()

  defp format_parsed_user_agent(%UAInspector.Result{
         browser_family: browser_family,
         os_family: os_family
       })
       when is_binary(browser_family) and is_binary(os_family),
       do: "#{browser_family} on #{os_family}"

  defp format_parsed_user_agent(_user_agent), do: "Unknown"
end
