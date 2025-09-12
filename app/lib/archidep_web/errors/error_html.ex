defmodule ArchiDepWeb.Errors.ErrorHTML do
  @moduledoc """
  Endpoint in case of errors on HTML requests. See config/config.exs.
  """
  use ArchiDepWeb, :html

  @custom_errors %{
    "404.html" =>
      {"This is not the page you're looking for.", "You can go about your business.",
       "Move along"}
  }

  @default_error {"Oops! Something seems to have gone wrong.",
                  "Our teams of engineers have been dispatched to fix it.",
                  "Take me back to safety!"}

  embed_templates "html/*"

  @spec render(String.t(), map()) :: Rendered.t()
  def render(template, assigns) do
    {line1, line2, button_text} = Map.get(@custom_errors, template, @default_error)

    fallback(%{
      status: Map.get(assigns, :status, 500),
      status_text: Phoenix.Controller.status_message_from_template(template),
      line1: line1,
      line2: line2,
      button_text: button_text
    })
  end
end
