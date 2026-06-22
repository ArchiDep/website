defmodule ArchiDepWeb.Servers.ServerPropertiesFormTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDepWeb.Servers.ServerPropertiesForm
  alias Ecto.Changeset

  describe "changeset/2" do
    test "casts every field" do
      params = %{
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

      changeset = ServerPropertiesForm.changeset(%ServerPropertiesForm{}, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerPropertiesForm{
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

    test "rejects an invalid integer field" do
      assert errors_on(
               ServerPropertiesForm.changeset(%ServerPropertiesForm{}, %{"cpus" => "abc"})
             ) ==
               %{cpus: ["is invalid"]}
    end
  end

  describe "from/1" do
    test "maps expected server properties to a form" do
      properties = %ExpectedServerProperties{
        id: "00000000-0000-0000-0000-000000000001",
        hostname: "host.example.com",
        machine_id: "machine-id",
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

      assert ServerPropertiesForm.from(properties) == %ServerPropertiesForm{
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

    test "maps server properties to a form" do
      properties = %ServerProperties{
        id: "00000000-0000-0000-0000-000000000002",
        hostname: "host.example.com",
        machine_id: "machine-id",
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

      assert ServerPropertiesForm.from(properties) == %ServerPropertiesForm{
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
  end

  describe "to_data/1" do
    test "maps a form to a server properties map" do
      form = %ServerPropertiesForm{
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

      assert ServerPropertiesForm.to_data(form) == %{
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
  end
end
