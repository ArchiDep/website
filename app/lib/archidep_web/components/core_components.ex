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

  slot :inner_block, required: true, doc: "the troubleshooting instruction to display"

  @spec troubleshooting_note(map()) :: Rendered.t()
  def troubleshooting_note(assigns) do
    ~H"""
    <div class="note note-troubleshooting">
      <div class="title">
        💥 <span>Troubleshooting</span>
      </div>
      <div class="content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
