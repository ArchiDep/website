defmodule ArchiDepWeb.Admin.Ansible.AnsibleComponents do
  @moduledoc false

  use ArchiDepWeb, :component

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  @ansible_stat_types [
    :changed,
    :failures,
    :ignored,
    :ok,
    :rescued,
    :skipped,
    :unreachable
  ]

  @ansible_stat_colors %{
    changed: "text-warning",
    failures: "text-error",
    ignored: "text-secondary",
    ok: "text-success",
    rescued: "text-info",
    skipped: "text-base-content/75",
    unreachable: "text-error"
  }

  attr :playbook_run, AnsiblePlaybookRun,
    required: true,
    doc: "the Ansible playbook run from which to retrieve the state"

  @spec ansible_playbook_run_state(map()) :: Rendered.t()
  def ansible_playbook_run_state(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @playbook_run.state == :pending do %>
        <Heroicons.clock solid class="size-4 text-info" />
        <span>{gettext("Pending")}</span>
      <% end %>
      <%= if @playbook_run.state == :running do %>
        <Heroicons.arrow_path solid class="size-4 text-warning animate-spin" />
        <span>{gettext("Running")}</span>
      <% end %>
      <%= if @playbook_run.state == :succeeded do %>
        <Heroicons.check_circle solid class="size-4 text-success" />
        <span>{gettext("Succeeded")}</span>
      <% end %>
      <%= if @playbook_run.state == :failed do %>
        <Heroicons.exclamation_circle solid class="size-4 text-error" />
        <span>{gettext("Failed")}</span>
      <% end %>
      <%= if @playbook_run.state == :interrupted do %>
        <Heroicons.exclamation_triangle outline class="size-4 text-base-content/75" />
        <span>{gettext("Interrupted")}</span>
      <% end %>
      <%= if @playbook_run.state == :timeout do %>
        <Heroicons.x_circle outline class="size-4 text-base-content/75" />
        <span>{gettext("Timeout")}</span>
      <% end %>
    </div>
    """
  end

  attr :playbook_run, AnsiblePlaybookRun,
    required: true,
    doc: "the Ansible playbook run from which to retrieve stats"

  @spec ansible_playbook_run_stats(map()) :: Rendered.t()
  def ansible_playbook_run_stats(assigns) do
    playbook_run = assigns.playbook_run

    assigns =
      assign(
        assigns,
        :total,
        Enum.reduce(@ansible_stat_types, 0, fn stat, acc ->
          acc + ansible_playbook_run_stat(playbook_run, stat)
        end)
      )

    ~H"""
    <div class="flex flex-wrap gap-y-1 [&>.ansible-stat]:before:content-[','] [&>.ansible-stat:first-child]:before:content-[''] [&>.ansible-stat]:before:text-base-content">
      <.ansible_stat playbook_run={@playbook_run} stat={:changed} />
      <.ansible_stat playbook_run={@playbook_run} stat={:failures} />
      <.ansible_stat playbook_run={@playbook_run} stat={:ignored} />
      <.ansible_stat playbook_run={@playbook_run} stat={:ok} />
      <.ansible_stat playbook_run={@playbook_run} stat={:rescued} />
      <.ansible_stat playbook_run={@playbook_run} stat={:skipped} />
      <.ansible_stat playbook_run={@playbook_run} stat={:unreachable} />

      <span :if={@total == 0} class="ansible-stat text-base-content/50">
        {gettext("N/A")}
      </span>
    </div>
    """
  end

  attr :playbook_run, AnsiblePlaybookRun,
    required: true,
    doc: "the Ansible playbook run from which to retrieve stats"

  attr :stat, :atom,
    required: true,
    doc:
      "the Ansible playbook stat to display (one of :changed, :failures, :ignored, :ok, :rescued, :skipped, :unreachable)",
    values: [:changed, :failures, :ignored, :ok, :rescued, :skipped, :unreachable]

  @spec ansible_stat(map()) :: Rendered.t()
  def ansible_stat(assigns) do
    stat = assigns.stat
    playbook_run = assigns.playbook_run

    assigns =
      assign(assigns,
        value: ansible_playbook_run_stat(playbook_run, stat),
        color_class: Map.fetch!(@ansible_stat_colors, stat)
      )

    ~H"""
    <span :if={@value != 0} class={["ansible-stat", @color_class]}>
      {translate_ansible_stat(@value, @stat)}
    </span>
    """
  end

  defp ansible_playbook_run_stat(run, stat) do
    stat_key = String.to_existing_atom("stats_#{stat}")
    Map.fetch!(run, stat_key)
  end

  defp translate_ansible_stat(count, :changed), do: gettext("{count} changed", count: count)
  defp translate_ansible_stat(count, :failures), do: gettext("{count} failed", count: count)
  defp translate_ansible_stat(count, :ignored), do: gettext("{count} ignored", count: count)
  defp translate_ansible_stat(count, :ok), do: gettext("{count} ok", count: count)
  defp translate_ansible_stat(count, :rescued), do: gettext("{count} rescued", count: count)
  defp translate_ansible_stat(count, :skipped), do: gettext("{count} skipped", count: count)

  defp translate_ansible_stat(count, :unreachable),
    do: gettext("{count} unreachable", count: count)
end
