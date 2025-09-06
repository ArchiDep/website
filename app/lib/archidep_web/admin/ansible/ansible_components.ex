defmodule ArchiDepWeb.Admin.Ansible.AnsibleComponents do
  @moduledoc false

  use ArchiDepWeb, :component

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

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
    doc: "the Ansible playbook run from which to retrieve stats"

  @spec ansible_playbook_run_stats(map()) :: Rendered.t()
  def ansible_playbook_run_stats(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-y-1 [&>.ansible-stat]:before:content-[','] [&>.ansible-stat:first-child]:before:content-[''] [&>.ansible-stat]:before:text-base-content">
      <.ansible_stat playbook_run={@playbook_run} stat={:changed} />
      <.ansible_stat playbook_run={@playbook_run} stat={:failures} />
      <.ansible_stat playbook_run={@playbook_run} stat={:ignored} />
      <.ansible_stat playbook_run={@playbook_run} stat={:ok} />
      <.ansible_stat playbook_run={@playbook_run} stat={:rescued} />
      <.ansible_stat playbook_run={@playbook_run} stat={:skipped} />
      <.ansible_stat playbook_run={@playbook_run} stat={:unreachable} />
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
    stat_key = String.to_existing_atom("stats_#{stat}")

    playbook_run = assigns.playbook_run

    assigns =
      assign(assigns,
        value: Map.fetch!(playbook_run, stat_key),
        color_class: Map.fetch!(@ansible_stat_colors, stat)
      )

    ~H"""
    <span :if={@value != 0} class={["ansible-stat", @color_class]}>
      {translate_ansible_stat(@value, @stat)}
    </span>
    """
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
