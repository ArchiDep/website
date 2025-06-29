defmodule ArchiDepWeb.Components.Notifications.Message do
  @moduledoc false

  use ArchiDepWeb, :html

  use Flashy.Normal, types: [:info, :success, :warning, :error]

  attr :key, :string, required: true
  attr :notification, Flashy.Normal, required: true

  def render(assigns) do
    ~H"""
    <Flashy.Normal.render key={@key} notification={@notification}>
      <div role="alert" class={["alert", color(@notification.type)]}>
        <.icon type={@notification.type} />
        <span>{Phoenix.HTML.raw(@notification.message)}</span>
        <Heroicons.x_mark
          class="w-4 h-4 cursor-pointer"
          phx-click={JS.exec("data-hide", to: "##{@key}")}
        />
        <.progress_bar :if={@notification.options.dismissible?} id={"#{@key}-progress"} />
      </div>
    </Flashy.Normal.render>
    """
  end

  attr :id, :string, required: true

  defp progress_bar(assigns) do
    ~H"""
    <div id={@id} class="absolute bottom-0 left-0 h-1 bg-black/30 w-0" />
    """
  end

  attr :type, :atom, required: true

  defp icon(%{type: :info} = assigns),
    do: ~H"""
    <Heroicons.information_circle class="w-4 h-4" />
    """

  defp icon(%{type: :success} = assigns),
    do: ~H"""
    <Heroicons.check_circle class="w-4 h-4" />
    """

  defp icon(%{type: :warning} = assigns),
    do: ~H"""
    <Heroicons.exclamation_triangle class="w-4 h-4" />
    """

  defp icon(%{type: :error} = assigns),
    do: ~H"""
    <Heroicons.exclamation_circle class="w-4 h-4" />
    """

  defp color(:info), do: "alert-info"
  defp color(:success), do: "alert-success"
  defp color(:warning), do: "alert-warning"
  defp color(:error), do: "alert-error"
end
