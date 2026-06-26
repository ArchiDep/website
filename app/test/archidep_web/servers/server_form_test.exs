defmodule ArchiDepWeb.Servers.ServerFormTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServersFactory
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Servers.ServerForm
  alias ArchiDepWeb.Servers.ServerPropertiesForm
  alias Ecto.Changeset

  # Minimal params that satisfy the non-root required fields, so the shared
  # value-validation tests can isolate the one field under test.
  @valid_params %{
    "ip_address" => "10.0.0.1",
    "username" => "bob",
    "ssh_host_key_fingerprints" => "fp"
  }

  # `create_changeset/2` and `update_changeset/2` run the same cast and value
  # validations; each rule is written once below and the `for` comprehension
  # generates one test per changeset function, dispatching through
  # `changeset/2`.
  for variant <- [:create, :update] do
    describe "#{variant}_changeset value validations" do
      test "an invalid SSH port is rejected" do
        assert errors_on(changeset(unquote(variant), Map.put(@valid_params, "ssh_port", "abc"))) ==
                 %{ssh_port: ["is invalid"]}
      end

      test "an invalid active flag is rejected" do
        assert errors_on(
                 changeset(unquote(variant), Map.put(@valid_params, "active", "notabool"))
               ) ==
                 %{active: ["is invalid"]}
      end

      test "a nested expected property error surfaces" do
        assert errors_on(
                 changeset(
                   unquote(variant),
                   Map.put(@valid_params, "expected_properties", %{"cpus" => "abc"})
                 )
               ) == %{expected_properties: %{cpus: ["is invalid"]}}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 changeset(
                   unquote(variant),
                   Map.merge(@valid_params, %{"ssh_port" => "abc", "active" => "notabool"})
                 )
               ) == %{ssh_port: ["is invalid"], active: ["is invalid"]}
      end
    end
  end

  describe "blank_changeset/0" do
    test "builds an unchanged form" do
      assert Changeset.apply_changes(ServerForm.blank_changeset()) == %ServerForm{}
    end
  end

  describe "create_changeset/2" do
    test "requires the core fields for a non-root user" do
      changeset = ServerForm.create_changeset(Factory.build(:authentication, root: false), %{})

      assert errors_on(changeset) == %{
               ip_address: ["can't be blank"],
               username: ["can't be blank"],
               ssh_host_key_fingerprints: ["can't be blank"]
             }
    end

    test "additionally requires the group for a root user" do
      changeset = ServerForm.create_changeset(Factory.build(:authentication, root: true), %{})

      assert errors_on(changeset) == %{
               group_id: ["can't be blank"],
               ip_address: ["can't be blank"],
               username: ["can't be blank"],
               ssh_host_key_fingerprints: ["can't be blank"]
             }
    end

    test "builds a form from minimal params" do
      changeset =
        ServerForm.create_changeset(Factory.build(:authentication, root: false), @valid_params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerForm{
               name: nil,
               ip_address: "10.0.0.1",
               username: "bob",
               ssh_port: nil,
               ssh_host_key_fingerprints: "fp",
               active: true,
               group_id: nil,
               app_username: "archidep",
               expected_properties: nil
             }
    end

    test "builds a form from full params, coercing the boolean form string" do
      params = %{
        "name" => "web-1",
        "ip_address" => "192.168.1.20",
        "username" => "deploy",
        "ssh_port" => "2222",
        "ssh_host_key_fingerprints" => "fp-full",
        "active" => "false",
        "app_username" => "myapp",
        "group_id" => "22222222-2222-2222-2222-222222222222",
        "expected_properties" => %{
          "cpus" => "4",
          "cores" => "2",
          "vcpus" => "8",
          "memory" => "2048",
          "swap" => "1024",
          "system" => "x86",
          "architecture" => "amd64",
          "os_family" => "Debian",
          "distribution" => "Ubuntu",
          "distribution_release" => "jammy",
          "distribution_version" => "22.04"
        }
      }

      changeset = ServerForm.create_changeset(Factory.build(:authentication, root: true), params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerForm{
               name: "web-1",
               ip_address: "192.168.1.20",
               username: "deploy",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "fp-full",
               active: false,
               group_id: "22222222-2222-2222-2222-222222222222",
               app_username: "myapp",
               expected_properties: %ServerPropertiesForm{
                 cpus: 4,
                 cores: 2,
                 vcpus: 8,
                 memory: 2048,
                 swap: 1024,
                 system: "x86",
                 architecture: "amd64",
                 os_family: "Debian",
                 distribution: "Ubuntu",
                 distribution_release: "jammy",
                 distribution_version: "22.04"
               }
             }
    end
  end

  describe "update_changeset/2" do
    test "updates every castable field, retaining the seeded group" do
      server = build(:server, server_attrs())

      params = %{
        "name" => "Updated",
        "ip_address" => "10.0.0.5",
        "username" => "newuser",
        "ssh_port" => "2222",
        "ssh_host_key_fingerprints" => "new-fp",
        "active" => "false",
        "app_username" => "newapp"
      }

      changeset = ServerForm.update_changeset(server, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerForm{
               name: "Updated",
               ip_address: "10.0.0.5",
               username: "newuser",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "new-fp",
               active: false,
               group_id: "11111111-1111-1111-1111-111111111111",
               app_username: "newapp",
               expected_properties: seeded_expected_properties_form()
             }
    end

    test "clears every optional field when given blank input" do
      server = build(:server, server_attrs())

      params = %{
        "name" => "",
        "ip_address" => "10.0.0.5",
        "username" => "newuser",
        "ssh_port" => "",
        "ssh_host_key_fingerprints" => "new-fp",
        "active" => "true",
        "app_username" => ""
      }

      changeset = ServerForm.update_changeset(server, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerForm{
               name: nil,
               ip_address: "10.0.0.5",
               username: "newuser",
               ssh_port: nil,
               ssh_host_key_fingerprints: "new-fp",
               active: true,
               group_id: "11111111-1111-1111-1111-111111111111",
               app_username: nil,
               expected_properties: seeded_expected_properties_form()
             }
    end

    test "rejects blank required fields" do
      changeset =
        ServerForm.update_changeset(build(:server, server_attrs()), %{
          "ip_address" => "",
          "username" => "",
          "ssh_host_key_fingerprints" => ""
        })

      assert errors_on(changeset) == %{
               ip_address: ["can't be blank"],
               username: ["can't be blank"],
               ssh_host_key_fingerprints: ["can't be blank"]
             }
    end
  end

  describe "to_create_data/1" do
    test "maps a full form, dropping the group and mapping the expected properties" do
      form = full_form()

      assert ServerForm.to_create_data(form) == %{
               name: "web-1",
               ip_address: "192.168.1.20",
               username: "deploy",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "fp-full",
               active: false,
               app_username: "myapp",
               expected_properties: seeded_expected_properties_map()
             }
    end

    test "maps blank expected properties to an empty map" do
      form = %{full_form() | expected_properties: nil}

      assert ServerForm.to_create_data(form) == %{
               name: "web-1",
               ip_address: "192.168.1.20",
               username: "deploy",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "fp-full",
               active: false,
               app_username: "myapp",
               expected_properties: %{}
             }
    end
  end

  describe "to_update_data/1" do
    test "maps a full form, dropping the group and mapping the expected properties" do
      form = full_form()

      assert ServerForm.to_update_data(form) == %{
               name: "web-1",
               ip_address: "192.168.1.20",
               username: "deploy",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "fp-full",
               active: false,
               app_username: "myapp",
               expected_properties: seeded_expected_properties_map()
             }
    end
  end

  defp changeset(:create, params),
    do: ServerForm.create_changeset(Factory.build(:authentication, root: false), params)

  defp changeset(:update, params), do: ServerForm.update_changeset(build(:server), params)

  # Options for the `build(:server, …)` fixture the update tests share: a known
  # group, a fixed IP address, and expected properties whose mapped fields match
  # `seeded_expected_properties_form/0`.
  defp server_attrs,
    do: [
      group_id: "11111111-1111-1111-1111-111111111111",
      ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
      expected_properties: %ServerProperties{
        id: "33333333-3333-3333-3333-333333333333",
        cpus: 4,
        cores: 2,
        vcpus: 8,
        memory: 2048,
        swap: 1024,
        system: "x86",
        architecture: "amd64",
        os_family: "Debian",
        distribution: "Ubuntu",
        distribution_release: "jammy",
        distribution_version: "22.04"
      }
    ]

  defp full_form,
    do: %ServerForm{
      name: "web-1",
      ip_address: "192.168.1.20",
      username: "deploy",
      ssh_port: 2222,
      ssh_host_key_fingerprints: "fp-full",
      active: false,
      group_id: "22222222-2222-2222-2222-222222222222",
      app_username: "myapp",
      expected_properties: seeded_expected_properties_form()
    }

  defp seeded_expected_properties_form,
    do: %ServerPropertiesForm{
      cpus: 4,
      cores: 2,
      vcpus: 8,
      memory: 2048,
      swap: 1024,
      system: "x86",
      architecture: "amd64",
      os_family: "Debian",
      distribution: "Ubuntu",
      distribution_release: "jammy",
      distribution_version: "22.04"
    }

  defp seeded_expected_properties_map,
    do: %{
      cpus: 4,
      cores: 2,
      vcpus: 8,
      memory: 2048,
      swap: 1024,
      system: "x86",
      architecture: "amd64",
      os_family: "Debian",
      distribution: "Ubuntu",
      distribution_release: "jammy",
      distribution_version: "22.04"
    }
end
