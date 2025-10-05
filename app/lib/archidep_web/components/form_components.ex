defmodule ArchiDepWeb.Components.FormComponents do
  @moduledoc """
  Common components and helper functions for rendering forms.
  """

  use ArchiDepWeb, :component

  slot(:inner_block, required: true, doc: "the help text to display")

  @spec field_help(map()) :: Rendered.t()
  def field_help(assigns) do
    ~H"""
    <div class="flex items-start gap-x-1">
      <Heroicons.information_circle class="mt-0.5 size-4 shrink-0 text-info/85" />
      <div class="text-sm text-info/85">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr(:current_value, :any, required: true, doc: "the current value of the field")
  attr(:old_value, :any, doc: "the old value of the field")

  attr(:show_old_value, :boolean,
    default: true,
    doc: "whether to show the old value if it differs from the current value"
  )

  attr(:new_value, :any, doc: "the new value of the field")

  attr(:new_value_style, :atom,
    default: :badge,
    values: [:badge, :raw],
    doc: "the display style to use for the new value"
  )

  attr(:process_value, {:fun, 1},
    default: &__MODULE__.process_value/1,
    doc: "a function to process the value before comparing it"
  )

  attr(:display_value, {:fun, 1},
    default: &Function.identity/1,
    doc: "a function to display the current, old and new values"
  )

  attr(:rest, :global, doc: "arbitrary HTML attributes to add to the container")

  slot(:value_display, doc: "custom value display")

  @spec concurrent_modification_warning(map()) :: Rendered.t()
  def concurrent_modification_warning(assigns) do
    current_value = assigns.current_value
    process_value_fn = assigns.process_value

    processed_value =
      case process_value_fn.(current_value) do
        {:ok, val} -> val
        _anything_else -> assigns.current_value
      end

    assigns = assign(assigns, :processed_value, processed_value)

    ~H"""
    <div
      :if={@new_value != @processed_value}
      class={["flex flex-wrap sm:flex-nowrap items-center gap-2", Map.get(@rest, :class)]}
    >
      <span
        :if={@new_value != @old_value or @new_value != @processed_value}
        class="text-sm italic text-warning"
      >
        {gettext("value has been modified")}
      </span>
      <div
        :if={@old_value != nil and @old_value != @processed_value and @show_old_value}
        class="badge badge-soft badge-warning badge-sm tooltip"
        data-tip={gettext("Previous value")}
      >
        {render_slot(@value_display, @old_value) || @display_value.(@old_value)}
      </div>
      <%= if @new_value != nil and @new_value != @processed_value do %>
        <%= if @new_value_style == :raw do %>
          {render_slot(@value_display, @new_value) || @display_value.(@new_value)}
        <% end %>
        <div
          :if={@new_value_style == :badge}
          class="badge badge-warning badge-sm tooltip"
          data-tip={gettext("New value")}
        >
          {render_slot(@value_display, @new_value) || @display_value.(@new_value)}
        </div>
      <% end %>
    </div>
    """
  end

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from a form, for example: @form[:email]"
  )

  @spec errors_for(map()) :: Rendered.t()
  def errors_for(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <.error :for={msg <- @errors}>{msg}</.error>
    """
  end

  slot(:inner_block, required: true)

  @spec error(map()) :: Rendered.t()
  def error(assigns) do
    ~H"""
    <p class="fieldset-label text-error text-sm text-left">
      <span class="flex items-start gap-x-1">
        <Heroicons.exclamation_circle class="mt-0.5 size-4 shrink-0" />
        <span>{render_slot(@inner_block)}</span>
      </span>
    </p>
    """
  end

  @spec translate_error({String.t(), Keyword.t()}) :: String.t()
  def translate_error({msg, opts}), do: Gettext.dgettext(ArchiDepWeb.Gettext, "errors", msg, opts)

  @spec process_value(arg) :: {:ok, arg} when arg: var
  def process_value(arg), do: {:ok, to_string(arg)}
end
