defmodule ArchiDepWeb.Components.CoreComponents do
  @moduledoc """
  Core UI components.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered

  attr :responsive, :boolean,
    default: true,
    doc: "whether to display elements horizontally on larger screens"

  attr :responsive_class, :string,
    default: "md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4",
    doc: "the responsive grid classes to use"

  attr :small, :boolean, default: false, doc: "whether to use a smaller layout"
  attr :rest, :global, doc: "arbitrary HTML attributes to add to the container"

  slot :inner_block, required: true, doc: "the data elements to display"

  @spec data_display(map()) :: Rendered.t()
  def data_display(assigns) do
    ~H"""
    <dl
      class={[
        "grid grid-cols-1",
        if(@responsive, do: @responsive_class),
        if(@small, do: "gap-2", else: "gap-4"),
        Map.get(@rest, :class)
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </dl>
    """
  end

  attr :title, :string, required: true, doc: "the title of the data to display"
  attr :small, :boolean, default: false, doc: "whether to use a smaller font size"
  attr :rest, :global, doc: "arbitrary HTML attributes to add to the definition container"
  slot :inner_block, required: true, doc: "the content to display"

  @spec data_display_element(map()) :: Rendered.t()
  def data_display_element(assigns) do
    ~H"""
    <div class="flex flex-col">
      <dt class={["mb-1 text-base-content/75", if(@small, do: "text-xs", else: "text-sm")]}>
        {@title}
      </dt>
      <dd class={[if(@small, do: "text-sm"), Map.get(@rest, :class)]} {@rest}>
        {render_slot(@inner_block)}
      </dd>
    </div>
    """
  end

  attr :text, :string, default: "-", doc: "the text to display"

  @spec no_data(map()) :: Rendered.t()
  def no_data(assigns) do
    ~H"""
    <span class="text-base-content/50 italic">
      {@text}
    </span>
    """
  end

  attr :rest, :global, doc: "arbitrary HTML attributes to add to the note container"
  slot :inner_block, required: true, doc: "the troubleshooting instruction to display"

  @spec troubleshooting_note(map()) :: Rendered.t()
  def troubleshooting_note(assigns) do
    ~H"""
    <div class={["note note-troubleshooting", Map.get(@rest, :class)]} {@rest}>
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
