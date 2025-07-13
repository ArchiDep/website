defmodule ArchiDepWeb.Components.FormComponents do
  use Phoenix.Component

  slot :inner_block, required: true, doc: "the help text to display"

  def field_help(assigns) do
    ~H"""
    <p class="flex items-start gap-x-1 text-info/85">
      <Heroicons.information_circle class="size-4" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from a form, for example: @form[:email]"

  def errors_for(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <.error :for={msg <- @errors}>{msg}</.error>
    """
  end

  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="fieldset-label text-error">
      <span class="flex items-center gap-x-1">
        <Heroicons.exclamation_circle class="size-3" />
        <span>{render_slot(@inner_block)}</span>
      </span>
    </p>
    """
  end

  def translate_error({msg, opts}), do: Gettext.dgettext(ArchiDepWeb.Gettext, "errors", msg, opts)
end
