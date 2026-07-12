# credo:disable-for-this-file Credo.Check.Readability.MaxLineLength
defmodule ArchiDep.Events.Store.EventSchemaVersionDriftTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Events.Store.Event

  # Every stored event records the `schema_version` its payload was written with
  # (resolved in `ArchiDep.Helpers.UseCaseHelpers.add_to_stream/2` from each
  # event's `event_version/0`, defaulting to 1), and readers rely on that number
  # to tell one payload shape from another. Nothing at compile time forces the
  # number to change when the shape does. This test reconstructs that guarantee:
  # it derives each event's current payload shape from its `@type t` and
  # compares the whole `%{module => {schema_version, shape}}` map against the
  # catalog pinned below. Changing an event struct (adding or removing a field,
  # a nested map key, or altering a field's type) fails here until the catalog
  # is updated with the event's new shape and a bumped `event_version/0`; adding
  # or removing an event fails too. The shape is derived recursively so a change
  # inside a nested map (e.g. a new key on an `owner`) is caught. Types defined
  # in another module are pinned by reference (e.g. `ansible_variables()`), so a
  # change to such a type is caught where it is defined, not here.

  @catalog %{
    ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount =>
      {1,
       "%{preregistered_user_id: Ecto.UUID.t(), user_account: %{active: boolean(), id: Ecto.UUID.t(), username: String.t(), version: pos_integer()}}"},
    ArchiDep.Accounts.Events.PreregisteredUserLoginLinkCreated =>
      {1,
       "%{id: Ecto.UUID.t(), preregistered_user: %{email: String.t() | nil, id: Ecto.UUID.t(), name: String.t() | nil}}"},
    ArchiDep.Accounts.Events.SessionDeleted =>
      {1,
       "%{preregistered_user: %{email: String.t() | nil, id: Ecto.UUID.t(), name: String.t() | nil} | nil, session_id: Ecto.UUID.t(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil} | nil, user_account: %{id: Ecto.UUID.t(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserImpersonated =>
      {1,
       "%{impersonated_user_account: %{id: Ecto.UUID.t(), preregistered_user: %{email: String.t() | nil, id: Ecto.UUID.t(), name: String.t() | nil} | nil, root: boolean(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil} | nil, username: String.t() | nil}, session_id: Ecto.UUID.t(), user_account: %{id: Ecto.UUID.t(), preregistered_user: %{email: String.t() | nil, id: Ecto.UUID.t(), name: String.t() | nil} | nil, root: boolean(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil} | nil, username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserLoggedInWithLink =>
      {1,
       "%{client_ip_address: String.t() | nil, client_user_agent: String.t() | nil, login_link: %{id: Ecto.UUID.t()}, preregistered_user: %{email: String.t(), id: Ecto.UUID.t(), name: String.t()} | nil, session_id: Ecto.UUID.t(), user_account: %{id: Ecto.UUID.t(), root: boolean(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId =>
      {1,
       "%{client_ip_address: String.t() | nil, client_user_agent: String.t() | nil, preregistered_user: %{email: String.t(), id: Ecto.UUID.t(), name: String.t()} | nil, session_id: Ecto.UUID.t(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil, swiss_edu_person_unique_id: String.t()}, user_account: %{id: Ecto.UUID.t(), root: boolean(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserLoggedOut =>
      {1,
       "%{preregistered_user: %{email: String.t() | nil, id: Ecto.UUID.t(), name: String.t() | nil} | nil, session_id: Ecto.UUID.t(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil} | nil, user_account: %{id: Ecto.UUID.t(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserRegisteredWithLink =>
      {1,
       "%{client_ip_address: String.t() | nil, client_user_agent: String.t() | nil, login_link: %{id: Ecto.UUID.t()}, preregistered_user: %{email: String.t(), id: Ecto.UUID.t(), name: String.t()} | nil, session_id: Ecto.UUID.t(), user_account: %{id: Ecto.UUID.t(), root: boolean(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId =>
      {1,
       "%{client_ip_address: String.t() | nil, client_user_agent: String.t() | nil, preregistered_user: %{email: String.t(), id: Ecto.UUID.t(), name: String.t()} | nil, session_id: Ecto.UUID.t(), switch_edu_id: %{first_name: String.t() | nil, id: Ecto.UUID.t(), last_name: String.t() | nil, swiss_edu_person_unique_id: String.t()}, user_account: %{id: Ecto.UUID.t(), root: boolean(), username: String.t() | nil}}"},
    ArchiDep.Accounts.Events.UserStoppedImpersonating =>
      {1,
       "%{impersonated_user_account: ArchiDep.Accounts.Events.UserImpersonated.account(), session_id: Ecto.UUID.t(), user_account: ArchiDep.Accounts.Events.UserImpersonated.account()}"},
    ArchiDep.Course.Events.ClassCreated =>
      {1,
       "%{active: boolean(), end_date: Date.t() | nil, id: Ecto.UUID.t(), name: String.t(), servers_enabled: boolean(), ssh_exercise_vm_md5_host_key_fingerprints: String.t() | nil, ssh_exercise_vm_sha256_host_key_fingerprints: String.t() | nil, start_date: Date.t() | nil, teacher_ssh_public_keys: [String.t()]}"},
    ArchiDep.Course.Events.ClassDeleted => {1, "%{id: Ecto.UUID.t(), name: String.t()}"},
    ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated =>
      {1,
       "%{architecture: String.t() | nil, class: %{id: Ecto.UUID.t(), name: String.t()}, cores: pos_integer() | nil, cpus: pos_integer() | nil, distribution: String.t() | nil, distribution_release: String.t() | nil, distribution_version: String.t() | nil, hostname: String.t() | nil, machine_id: String.t() | nil, memory: pos_integer() | nil, os_family: String.t() | nil, swap: pos_integer() | nil, system: String.t() | nil, vcpus: pos_integer() | nil}"},
    ArchiDep.Course.Events.ClassUpdated =>
      {1,
       "%{active: boolean(), end_date: Date.t() | nil, id: Ecto.UUID.t(), name: String.t(), servers_enabled: boolean(), ssh_exercise_vm_md5_host_key_fingerprints: String.t() | nil, ssh_exercise_vm_sha256_host_key_fingerprints: String.t() | nil, start_date: Date.t() | nil, teacher_ssh_public_keys: [String.t()]}"},
    ArchiDep.Course.Events.StudentConfigured =>
      {1,
       "%{class: %{id: Ecto.UUID.t(), name: String.t()}, email: String.t(), id: Ecto.UUID.t(), name: String.t(), username: String.t()}"},
    ArchiDep.Course.Events.StudentCreated =>
      {1,
       "%{academic_class: String.t() | nil, active: boolean(), class: %{id: Ecto.UUID.t(), name: String.t()}, domain: String.t(), email: String.t(), id: Ecto.UUID.t(), name: String.t(), servers_enabled: boolean(), username: String.t()}"},
    ArchiDep.Course.Events.StudentDeleted =>
      {1,
       "%{class: %{id: Ecto.UUID.t(), name: String.t()}, email: String.t(), id: Ecto.UUID.t(), name: String.t()}"},
    ArchiDep.Course.Events.StudentUpdated =>
      {1,
       "%{academic_class: String.t() | nil, active: boolean(), class: %{id: Ecto.UUID.t(), name: String.t()}, domain: String.t(), email: String.t(), id: Ecto.UUID.t(), name: String.t(), servers_enabled: boolean(), username: String.t()}"},
    ArchiDep.Course.Events.StudentsImportedInClass =>
      {1,
       "%{academic_class: String.t() | nil, class_id: Ecto.UUID.t(), class_name: String.t(), domain: String.t(), number_of_students: non_neg_integer()}"},
    ArchiDep.Servers.Events.AnsiblePlaybookEventOccurred =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, playbook_run: %{host: String.t(), id: Ecto.UUID.t(), playbook: String.t(), port: 1..65535, user: String.t()}, properties: %{required(String.t()) => term()}, server: %{id: Ecto.UUID.t(), name: String.t() | nil, username: String.t()}}"},
    ArchiDep.Servers.Events.AnsiblePlaybookRunFinished =>
      {1,
       "%{exit_code: 0..255, group: %{id: Ecto.UUID.t(), name: String.t()}, host: String.t(), id: Ecto.UUID.t(), number_of_events: non_neg_integer(), owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, playbook: String.t(), port: 1..65535, server: %{id: Ecto.UUID.t(), name: String.t() | nil, username: String.t()}, state: String.t(), stats: %{changed: non_neg_integer(), failures: non_neg_integer(), ignored: non_neg_integer(), ok: non_neg_integer(), rescued: non_neg_integer(), skipped: non_neg_integer(), unreachable: non_neg_integer()}, user: String.t()}"},
    ArchiDep.Servers.Events.AnsiblePlaybookRunRunning =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, host: String.t(), id: Ecto.UUID.t(), owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, playbook: String.t(), port: 1..65535, server: %{id: Ecto.UUID.t(), name: String.t() | nil, username: String.t()}, user: String.t()}"},
    ArchiDep.Servers.Events.AnsiblePlaybookRunStarted =>
      {1,
       "%{git_revision: String.t(), group: %{id: Ecto.UUID.t(), name: String.t()}, host: String.t(), id: Ecto.UUID.t(), owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, playbook: String.t(), playbook_digest: String.t(), playbook_path: String.t(), port: 1..65535, server: %{id: Ecto.UUID.t(), name: String.t() | nil, username: String.t()}, user: String.t(), vars: ArchiDep.Servers.Types.ansible_variables(), vars_digest: String.t()}"},
    ArchiDep.Servers.Events.ServerConnected =>
      {1,
       "%{connection_duration: non_neg_integer(), group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerCreated =>
      {1,
       "%{active: boolean(), app_username: String.t(), expected_properties: %{architecture: String.t() | nil, cores: non_neg_integer() | nil, cpus: non_neg_integer() | nil, distribution: String.t() | nil, distribution_release: String.t() | nil, distribution_version: String.t() | nil, hostname: String.t() | nil, machine_id: String.t() | nil, memory: non_neg_integer() | nil, os_family: String.t() | nil, swap: non_neg_integer() | nil, system: String.t() | nil, vcpus: non_neg_integer() | nil}, group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_host_key_fingerprints: String.t(), ssh_port: 1..65535 | nil, username: String.t()}"},
    ArchiDep.Servers.Events.ServerDeleted =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t(), owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535}"},
    ArchiDep.Servers.Events.ServerDisconnected =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, reason: String.t() | nil, ssh_port: 1..65535 | nil, ssh_username: String.t(), uptime: non_neg_integer(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerFactsGathered =>
      {2,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), last_known_properties: %{architecture: String.t() | nil, cores: non_neg_integer() | nil, cpus: non_neg_integer() | nil, distribution: String.t() | nil, distribution_release: String.t() | nil, distribution_version: String.t() | nil, hostname: String.t() | nil, id: Ecto.UUID.t(), machine_id: String.t() | nil, memory: non_neg_integer() | nil, os_family: String.t() | nil, swap: non_neg_integer() | nil, system: String.t() | nil, vcpus: non_neg_integer() | nil}, name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerNotifiedUp =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, username: String.t()}"},
    ArchiDep.Servers.Events.ServerOpenPortsChecked =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ports: [1..65535], ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerReconnecting =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerRetriedAnsiblePlaybook =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, playbook: String.t(), ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerRetriedCheckingOpenPorts =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ports: [1..65535], ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerRetriedConnecting =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerSetUp =>
      {1,
       "%{group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_port: 1..65535 | nil, ssh_username: String.t(), username: String.t()}"},
    ArchiDep.Servers.Events.ServerUpdated =>
      {1,
       "%{active: boolean(), app_username: String.t() | nil, expected_properties: %{architecture: String.t() | nil, cores: non_neg_integer() | nil, cpus: non_neg_integer() | nil, distribution: String.t() | nil, distribution_release: String.t() | nil, distribution_version: String.t() | nil, hostname: String.t() | nil, machine_id: String.t() | nil, memory: non_neg_integer() | nil, os_family: String.t() | nil, swap: non_neg_integer() | nil, system: String.t() | nil, vcpus: non_neg_integer() | nil}, group: %{id: Ecto.UUID.t(), name: String.t()}, id: Ecto.UUID.t(), ip_address: String.t(), name: String.t() | nil, owner: %{id: Ecto.UUID.t(), name: String.t() | nil, root: boolean(), username: String.t() | nil}, ssh_host_key_fingerprints: String.t(), ssh_port: 1..65535 | nil, username: String.t()}"}
  }

  test "each event's payload shape matches its pinned schema_version" do
    modules = event_modules()
    Enum.each(modules, &Code.ensure_loaded!/1)

    catalog =
      Map.new(modules, fn module -> {module, {schema_version(module), shape(module)}} end)

    assert catalog == @catalog
  end

  # The event set is enumerated from the protocol whether or not it has been
  # consolidated (consolidation is off in some `:test` runs so implementations
  # can be defined at runtime).
  defp event_modules do
    case Event.__protocol__(:impls) do
      {:consolidated, modules} -> modules
      :not_consolidated -> Protocol.extract_impls(Event, :code.get_path())
    end
  end

  defp schema_version(module),
    do: if(function_exported?(module, :event_version, 0), do: module.event_version(), else: 1)

  # Render an event's payload shape as a canonical, recursive signature derived
  # from its `@type t`: field names with their types, nested maps expanded,
  # local type aliases inlined, all fields sorted so the signature is
  # order-independent.
  defp shape(module) do
    local = local_types(module)
    local |> Map.fetch!(:t) |> canonical(local, MapSet.new()) |> render()
  end

  defp local_types(module) do
    {:ok, types} = Code.Typespec.fetch_types(module)

    for {kind, {name, _def, []} = tuple} <- types, kind in [:type, :typep, :opaque], into: %{} do
      {:"::", _meta, [_lhs, rhs]} = Code.Typespec.type_to_quoted(tuple)
      {name, rhs}
    end
  end

  defp canonical({:%, _meta, [_module, {:%{}, _inner_meta, fields}]}, local, seen),
    do: {:map, canonical_fields(fields, local, seen)}

  defp canonical({:%{}, _meta, fields}, local, seen),
    do: {:map, canonical_fields(fields, local, seen)}

  defp canonical({:|, _meta, [left, right]}, local, seen),
    do: {:union, canonical(left, local, seen), canonical(right, local, seen)}

  defp canonical(list, local, seen) when is_list(list),
    do: {:list, Enum.map(list, &canonical(&1, local, seen))}

  defp canonical({name, _meta, args}, local, seen) when is_atom(name) and is_list(args) do
    if Map.has_key?(local, name) and name != :t and not MapSet.member?(seen, name) do
      canonical(Map.fetch!(local, name), local, MapSet.put(seen, name))
    else
      Macro.to_string({name, [], args})
    end
  end

  defp canonical(leaf, _local, _seen), do: Macro.to_string(leaf)

  defp canonical_fields(fields, local, seen) do
    fields
    |> Enum.map(fn {key, value} ->
      {field_key(key, local, seen), canonical(value, local, seen)}
    end)
    |> Enum.sort_by(fn {key, _value} -> key end)
  end

  defp field_key(key, _local, _seen) when is_atom(key), do: {:name, Atom.to_string(key)}
  defp field_key(key, local, seen), do: {:pair, render(canonical(key, local, seen))}

  defp render({:map, fields}) do
    inner =
      Enum.map_join(fields, ", ", fn
        {{:name, name}, value} -> "#{name}: #{render(value)}"
        {{:pair, key}, value} -> "#{key} => #{render(value)}"
      end)

    "%{" <> inner <> "}"
  end

  defp render({:union, left, right}), do: render(left) <> " | " <> render(right)
  defp render({:list, elements}), do: "[" <> Enum.map_join(elements, ", ", &render/1) <> "]"
  defp render(leaf) when is_binary(leaf), do: leaf
end
