defmodule ArchiDepWeb.Components.Notifications.Disconnected do
  @moduledoc false

  use ArchiDepWeb, :html

  use Flashy.Disconnected

  attr :key, :string, required: true

  @spec render(map()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <Flashy.Disconnected.render key={@key}>
      <div role="alert" class="alert alert-warning">
        <Heroicons.arrow_path class="w-3 h-3 inline animate-spin" />
        {gettext("Oops, we've lost the internet; attempting to reconnect...")}
      </div>
    </Flashy.Disconnected.render>
    """
  end
end
