defmodule ArchiDepWeb.Components.CoreComponents do
  @moduledoc """
  Core UI components.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered

  @spec no_data(map()) :: Rendered.t()
  def no_data(assigns) do
    assigns = assign_new(assigns, :text, fn -> "-" end)

    ~H"""
    <span class="text-base-content/50 italic">
      {@text}
    </span>
    """
  end
end
