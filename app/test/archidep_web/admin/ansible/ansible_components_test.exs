defmodule ArchiDepWeb.Admin.Ansible.AnsibleComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Ansible.AnsibleComponents

  @stat_fields [
    stats_changed: 0,
    stats_failures: 0,
    stats_ignored: 0,
    stats_ok: 0,
    stats_rescued: 0,
    stats_skipped: 0,
    stats_unreachable: 0
  ]

  describe "ansible_playbook_run_state/1" do
    test "renders a pending run" do
      assert state_label(:pending) == "Pending"
    end

    test "renders a running run" do
      assert state_label(:running) == "Running"
    end

    test "renders a succeeded run" do
      assert state_label(:succeeded) == "Succeeded"
    end

    test "renders a failed run" do
      assert state_label(:failed) == "Failed"
    end

    test "renders an interrupted run" do
      assert state_label(:interrupted) == "Interrupted"
    end

    test "renders a timed-out run" do
      assert state_label(:timeout) == "Timeout"
    end
  end

  describe "ansible_playbook_run_stats/1" do
    test "renders every non-zero stat in display order" do
      run =
        build_run(
          stats_changed: 3,
          stats_failures: 1,
          stats_ignored: 2,
          stats_ok: 4,
          stats_rescued: 1,
          stats_skipped: 5,
          stats_unreachable: 2
        )

      assert stat_labels(run) == [
               "3 changed",
               "1 failed",
               "2 ignored",
               "4 ok",
               "1 rescued",
               "5 skipped",
               "2 unreachable"
             ]
    end

    test "omits stats that are zero" do
      run = build_run(stats_ok: 4, stats_failures: 2)

      assert stat_labels(run) == ["2 failed", "4 ok"]
    end

    test "renders a single N/A entry when every stat is zero" do
      assert stat_labels(build_run()) == ["N/A"]
    end
  end

  describe "ansible_stat/1" do
    test "renders a changed stat as a warning" do
      assert stat(:stats_changed, :changed, 5) == {"5 changed", ["ansible-stat", "text-warning"]}
    end

    test "renders a failures stat as an error" do
      assert stat(:stats_failures, :failures, 5) == {"5 failed", ["ansible-stat", "text-error"]}
    end

    test "renders an ignored stat as secondary" do
      assert stat(:stats_ignored, :ignored, 5) ==
               {"5 ignored", ["ansible-stat", "text-secondary"]}
    end

    test "renders an ok stat as a success" do
      assert stat(:stats_ok, :ok, 5) == {"5 ok", ["ansible-stat", "text-success"]}
    end

    test "renders a rescued stat as informational" do
      assert stat(:stats_rescued, :rescued, 5) == {"5 rescued", ["ansible-stat", "text-info"]}
    end

    test "renders a skipped stat as muted" do
      assert stat(:stats_skipped, :skipped, 5) ==
               {"5 skipped", ["ansible-stat", "text-base-content/75"]}
    end

    test "renders an unreachable stat as an error" do
      assert stat(:stats_unreachable, :unreachable, 5) ==
               {"5 unreachable", ["ansible-stat", "text-error"]}
    end

    test "renders nothing when the stat is zero" do
      assert stat(:stats_changed, :changed, 0) == nil
    end
  end

  defp state_label(state) do
    rendered =
      render_component(&AnsibleComponents.ansible_playbook_run_state/1,
        playbook_run: build_run(state: state)
      )

    html_element_text(rendered)
  end

  defp stat_labels(run) do
    rendered =
      render_component(&AnsibleComponents.ansible_playbook_run_stats/1, playbook_run: run)

    rendered
    |> find_html_elements(".ansible-stat")
    |> Enum.map(&html_element_text/1)
  end

  defp stat(field, stat, value) do
    html =
      render_component(&AnsibleComponents.ansible_stat/1,
        playbook_run: build_run([{field, value}]),
        stat: stat
      )

    case find_html_elements(html, ".ansible-stat") do
      [] -> nil
      [span] -> {html_element_text(span), class_tokens(span)}
    end
  end

  defp build_run(overrides \\ []),
    do:
      ServersFactory.build(:ansible_playbook_run, Map.new(Keyword.merge(@stat_fields, overrides)))

  defp class_tokens(element),
    do: element |> html_element_attribute("class") |> String.split() |> Enum.sort()
end
