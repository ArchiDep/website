defmodule ArchiDep.Servers.Schemas.ServerPropertiesTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServersFactory
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias Ecto.Changeset

  @no_expected_properties [
    hostname: nil,
    machine_id: nil,
    cpus: nil,
    cores: nil,
    vcpus: nil,
    memory: nil,
    swap: nil,
    system: nil,
    architecture: nil,
    os_family: nil,
    distribution: nil,
    distribution_release: nil,
    distribution_version: nil
  ]

  describe "changeset validation (new/3 and update/2)" do
    for variant <- [:new, :update] do
      test "#{variant}: blank data is valid (every field is optional)" do
        assert errors_on(changeset(unquote(variant), %{})) == %{}
      end

      test "#{variant}: a full set of valid properties is valid" do
        assert errors_on(
                 changeset(unquote(variant), %{
                   hostname: "host",
                   machine_id: "machine-id",
                   cpus: 2,
                   cores: 4,
                   vcpus: 8,
                   memory: 4096,
                   swap: 2048,
                   system: "Linux",
                   architecture: "x86_64",
                   os_family: "Debian",
                   distribution: "Ubuntu",
                   distribution_release: "noble",
                   distribution_version: "24.04"
                 })
               ) == %{}
      end

      # Every string field has the same length rule (only the limit differs), so
      # the limits are listed once and the comprehension generates one test each.
      for {field, max} <- [
            hostname: 255,
            machine_id: 255,
            system: 50,
            architecture: 20,
            os_family: 50,
            distribution: 50,
            distribution_release: 50,
            distribution_version: 20
          ] do
        test "#{variant}: #{field} cannot be longer than #{max} characters" do
          field = unquote(field)
          max = unquote(max)

          assert errors_on(
                   changeset(unquote(variant), %{field => String.duplicate("a", max + 1)})
                 ) ==
                   %{field => ["should be at most #{max} character(s)"]}
        end
      end

      # Same numeric rule for every integer field (only the upper bound differs).
      # The `{number}` placeholder is resolved by the translation layer at render
      # time, so the raw changeset error keeps it literal.
      for {field, max} <- [
            cpus: 32_767,
            cores: 32_767,
            vcpus: 32_767,
            memory: 2_147_483_647,
            swap: 2_147_483_647
          ] do
        test "#{variant}: #{field} cannot be negative" do
          assert errors_on(changeset(unquote(variant), %{unquote(field) => -1})) ==
                   %{unquote(field) => ["must be between 0 and {number}"]}
        end

        test "#{variant}: #{field} cannot exceed #{max}" do
          assert errors_on(changeset(unquote(variant), %{unquote(field) => unquote(max) + 1})) ==
                   %{unquote(field) => ["must be between 0 and {number}"]}
        end

        test "#{variant}: #{field} accepts its boundary values" do
          assert errors_on(changeset(unquote(variant), %{unquote(field) => 0})) == %{}
          assert errors_on(changeset(unquote(variant), %{unquote(field) => unquote(max)})) == %{}
        end
      end

      test "#{variant}: string fields are trimmed" do
        applied =
          unquote(variant)
          |> changeset(%{
            hostname: "  host  ",
            machine_id: "\tmachine-id\n",
            system: " Linux ",
            architecture: " x86_64 ",
            os_family: " Debian ",
            distribution: " Ubuntu ",
            distribution_release: " noble ",
            distribution_version: " 24.04 "
          })
          |> Changeset.apply_changes()

        assert applied == %ServerProperties{
                 id: applied.id,
                 hostname: "host",
                 machine_id: "machine-id",
                 system: "Linux",
                 architecture: "x86_64",
                 os_family: "Debian",
                 distribution: "Ubuntu",
                 distribution_release: "noble",
                 distribution_version: "24.04"
               }
      end

      test "#{variant}: blank string fields are stored as nil" do
        properties = build(:server_properties, hostname: "set")

        applied =
          unquote(variant)
          |> changeset(properties, %{hostname: "   "})
          |> Changeset.apply_changes()

        assert applied == %{properties | hostname: nil, id: applied.id}
      end

      test "#{variant}: validation errors accumulate across fields" do
        assert errors_on(
                 changeset(unquote(variant), %{
                   hostname: String.duplicate("a", 256),
                   cpus: -1,
                   memory: 2_147_483_648
                 })
               ) == %{
                 hostname: ["should be at most 255 character(s)"],
                 cpus: ["must be between 0 and {number}"],
                 memory: ["must be between 0 and {number}"]
               }
      end
    end
  end

  describe "new/3" do
    test "sets the given id and casts no other field from blank data" do
      id = Ecto.UUID.generate()

      changeset = ServerProperties.new(%ServerProperties{}, id, %{})

      assert errors_on(changeset) == %{}
      assert Changeset.apply_changes(changeset) == %ServerProperties{id: id}
    end
  end

  describe "blank_changeset/1" do
    test "produces a valid changeset that sets the given id" do
      id = Ecto.UUID.generate()

      changeset = ServerProperties.blank_changeset(id)

      assert errors_on(changeset) == %{}
      assert Changeset.apply_changes(changeset) == %ServerProperties{id: id}
    end
  end

  describe "update_from_ansible_facts/2" do
    test "maps every ansible fact to its property" do
      id = Ecto.UUID.generate()

      changeset =
        ServerProperties.update_from_ansible_facts(%ServerProperties{id: id}, %{
          "ansible_nodename" => "host",
          "ansible_machine_id" => "machine-id",
          "ansible_processor_count" => 2,
          "ansible_processor_cores" => 4,
          "ansible_processor_vcpus" => 8,
          "ansible_memory_mb" => %{"real" => %{"total" => 4096}, "swap" => %{"total" => 2048}},
          "ansible_system" => "Linux",
          "ansible_architecture" => "x86_64",
          "ansible_os_family" => "Debian",
          "ansible_distribution" => "Ubuntu",
          "ansible_distribution_release" => "noble",
          "ansible_distribution_version" => "24.04"
        })

      assert Changeset.apply_changes(changeset) == %ServerProperties{
               id: id,
               hostname: "host",
               machine_id: "machine-id",
               cpus: 2,
               cores: 4,
               vcpus: 8,
               memory: 4096,
               swap: 2048,
               system: "Linux",
               architecture: "x86_64",
               os_family: "Debian",
               distribution: "Ubuntu",
               distribution_release: "noble",
               distribution_version: "24.04"
             }
    end

    test "clears wrong-typed, over-range and over-length facts without rejecting the update" do
      id = Ecto.UUID.generate()

      changeset =
        ServerProperties.update_from_ansible_facts(%ServerProperties{id: id}, %{
          "ansible_nodename" => String.duplicate("a", 256),
          "ansible_processor_count" => "not-a-number",
          "ansible_memory_mb" => %{
            "real" => %{"total" => 2_147_483_648},
            "swap" => %{"total" => 2048}
          },
          "ansible_system" => "Linux"
        })

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ServerProperties{
               id: id,
               hostname: nil,
               cpus: nil,
               memory: nil,
               swap: 2048,
               system: "Linux"
             }
    end

    test "keeps the last known good value when a fact becomes invalid" do
      properties = build_server_properties(hostname: "old-host", cpus: 2)

      changeset =
        ServerProperties.update_from_ansible_facts(properties, %{
          "ansible_nodename" => String.duplicate("a", 256),
          "ansible_processor_count" => 4
        })

      assert errors_on(changeset) == %{}
      assert Changeset.apply_changes(changeset) == %{properties | cpus: 4}
    end
  end

  describe "blank/1" do
    test "builds a struct carrying only the given id" do
      id = Ecto.UUID.generate()

      assert ServerProperties.blank(id) == %ServerProperties{id: id}
    end
  end

  describe "changed?/2" do
    test "is false when both structs have the same significant fields" do
      properties = build(:server_properties)

      assert ServerProperties.changed?(properties, properties) == false
    end

    test "is false when only the id differs (the id is not a significant field)" do
      properties = build(:server_properties)

      assert ServerProperties.changed?(properties, %{properties | id: Ecto.UUID.generate()}) ==
               false
    end

    for {field, other_value} <- [
          hostname: "other-host",
          machine_id: "other-machine-id",
          cpus: 11,
          cores: 12,
          vcpus: 13,
          memory: 14,
          swap: 15,
          system: "BSD",
          architecture: "arm64",
          os_family: "RedHat",
          distribution: "Fedora",
          distribution_release: "rawhide",
          distribution_version: "40"
        ] do
      test "is true when #{field} differs" do
        properties =
          build_server_properties(
            hostname: "host",
            machine_id: "machine-id",
            cpus: 1,
            cores: 2,
            vcpus: 3,
            memory: 4,
            swap: 5,
            system: "Linux",
            architecture: "x86_64",
            os_family: "Debian",
            distribution: "Ubuntu",
            distribution_release: "noble",
            distribution_version: "24.04"
          )

        assert ServerProperties.changed?(
                 properties,
                 %{properties | unquote(field) => unquote(other_value)}
               ) == true
      end
    end
  end

  describe "merge/2" do
    test "keeps the original value where the override is nil, replaces it otherwise" do
      properties =
        build_server_properties(
          hostname: "host",
          machine_id: "machine-id",
          cpus: 2,
          cores: 4,
          system: "Linux"
        )

      overrides =
        build_server_properties(
          hostname: nil,
          machine_id: "other-machine",
          cpus: nil,
          cores: 8,
          system: "BSD"
        )

      assert ServerProperties.merge(properties, overrides) ==
               build_server_properties(
                 id: properties.id,
                 hostname: "host",
                 machine_id: "other-machine",
                 cpus: 2,
                 cores: 8,
                 system: "BSD"
               )
    end

    test "treats \"*\" on a string and 0 on an integer as clear-to-nil overrides" do
      properties =
        build_server_properties(
          hostname: "host",
          system: "Linux",
          cpus: 2,
          cores: 4
        )

      overrides =
        build_server_properties(
          hostname: "*",
          system: "*",
          cpus: 0,
          cores: 0
        )

      assert ServerProperties.merge(properties, overrides) ==
               build_server_properties(
                 id: properties.id,
                 hostname: nil,
                 system: nil,
                 cpus: nil,
                 cores: nil
               )
    end
  end

  describe "refresh/2" do
    test "copies every property from the map onto the struct" do
      id = Ecto.UUID.generate()

      refreshed =
        ServerProperties.refresh(%ServerProperties{id: id}, %{
          id: id,
          hostname: "host",
          machine_id: "machine-id",
          cpus: 2,
          cores: 4,
          vcpus: 8,
          memory: 4096,
          swap: 2048,
          system: "Linux",
          architecture: "x86_64",
          os_family: "Debian",
          distribution: "Ubuntu",
          distribution_release: "noble",
          distribution_version: "24.04"
        })

      assert refreshed == %ServerProperties{
               id: id,
               hostname: "host",
               machine_id: "machine-id",
               cpus: 2,
               cores: 4,
               vcpus: 8,
               memory: 4096,
               swap: 2048,
               system: "Linux",
               architecture: "x86_64",
               os_family: "Debian",
               distribution: "Ubuntu",
               distribution_release: "noble",
               distribution_version: "24.04"
             }
    end
  end

  describe "set_default_hostname/2" do
    test "leaves the properties unchanged when the default hostname is nil" do
      properties = build(:server_properties, hostname: "host")

      assert ServerProperties.set_default_hostname(properties, nil) == properties
    end

    test "sets the hostname when it is nil" do
      properties = build(:server_properties, hostname: nil)

      assert ServerProperties.set_default_hostname(properties, "default") ==
               %{properties | hostname: "default"}
    end

    test "leaves an existing hostname unchanged" do
      properties = build(:server_properties, hostname: "host")

      assert ServerProperties.set_default_hostname(properties, "default") == properties
    end
  end

  describe "detect_mismatches/2" do
    test "detect no property mismatches when there are no properties" do
      expected = build(:server_properties)
      actual = build(:server_properties, @no_expected_properties)

      assert ServerProperties.detect_mismatches(expected, actual) == []
    end

    test "detect no property mismatches when all properties match" do
      props = build(:server_properties)

      assert ServerProperties.detect_mismatches(props, props) == []
    end

    test "detect server property mismatches" do
      expected =
        build_server_properties(
          hostname: "host",
          machine_id: "machine-id",
          cpus: 2,
          cores: 4,
          vcpus: 8,
          memory: 4096,
          swap: 2048,
          system: "system",
          architecture: "arch",
          os_family: "family",
          distribution: "distro",
          distribution_release: "release",
          distribution_version: "version"
        )

      actual =
        build_server_properties(
          hostname: "host2",
          machine_id: "machine-id2",
          cpus: 4,
          cores: 8,
          vcpus: 16,
          memory: 8192,
          swap: 4096,
          system: "system2",
          architecture: "arch2",
          os_family: "family2",
          distribution: "distro2",
          distribution_release: "release2",
          distribution_version: "version2"
        )

      sorted_mismatches =
        expected
        |> ServerProperties.detect_mismatches(actual)
        |> Enum.sort_by(&(&1 |> elem(0) |> Atom.to_string()))

      assert sorted_mismatches == [
               {:architecture, "arch", "arch2"},
               {:cores, 4, 8},
               {:cpus, 2, 4},
               {:distribution, "distro", "distro2"},
               {:distribution_release, "release", "release2"},
               {:distribution_version, "version", "version2"},
               {:hostname, "host", "host2"},
               {:machine_id, "machine-id", "machine-id2"},
               {:memory, 4096, 8192},
               {:os_family, "family", "family2"},
               {:swap, 2048, 4096},
               {:system, "system", "system2"},
               {:vcpus, 8, 16}
             ]
    end

    test "no mismatches are detected for unspecified expected properties" do
      expected = build_server_properties(hostname: nil, cpus: nil)
      actual = build_server_properties(hostname: "host", cpus: 4)

      assert ServerProperties.detect_mismatches(expected, actual) == []
    end

    test "trims leading/trailing whitespace for all string properties before comparison" do
      expected =
        build_server_properties(
          hostname: "\thost\n",
          machine_id: "\nmachine-id\t  ",
          system: "  \nsystem\t  ",
          architecture: "\tarch \n",
          os_family: " \tfamily\n",
          distribution: "\ndistro \t",
          distribution_release: "\trelease  \n",
          distribution_version: "  \nversion\t"
        )

      actual =
        build_server_properties(
          hostname: "\nhost \t",
          machine_id: " \tmachine-id\n",
          system: "\tsystem\n ",
          architecture: " arch\t\n",
          os_family: "\nfamily \t",
          distribution: " \tdistro\n",
          distribution_release: "release\n \t",
          distribution_version: "\tversion \n"
        )

      assert ServerProperties.detect_mismatches(expected, actual) == []
    end

    test "a 20% discrepancy is allowed for the memory property" do
      for {expected_memory, actual_memory} <- [
            {1024, 1024},
            {1024, 848},
            {4096, 4915},
            {4096, 3277},
            {8192, 6554},
            {8192, 9830}
          ] do
        expected = build_server_properties(memory: expected_memory)
        actual = build_server_properties(memory: actual_memory)

        assert ServerProperties.detect_mismatches(expected, actual) == []
      end

      for {expected_memory, actual_memory} <- [
            {1024, 819},
            {4096, 3276},
            {8192, 6553},
            {4096, 4916},
            {8192, 9831}
          ] do
        expected = build_server_properties(memory: expected_memory)
        actual = build_server_properties(memory: actual_memory)

        assert ServerProperties.detect_mismatches(expected, actual) == [
                 {:memory, expected_memory, actual_memory}
               ]
      end
    end

    test "a 10% discrepancy is allowed for the swap property" do
      for {expected_swap, actual_swap} <- [
            {1024, 1024},
            {1024, 922},
            {4096, 4505},
            {4096, 3687},
            {8192, 7373},
            {8192, 9011}
          ] do
        expected = build_server_properties(swap: expected_swap)
        actual = build_server_properties(swap: actual_swap)

        assert ServerProperties.detect_mismatches(expected, actual) == []
      end

      for {expected_swap, actual_swap} <- [
            {1024, 921},
            {4096, 3685},
            {8192, 7371},
            {4096, 4506},
            {8192, 9012}
          ] do
        expected = build_server_properties(swap: expected_swap)
        actual = build_server_properties(swap: actual_swap)

        assert ServerProperties.detect_mismatches(expected, actual) == [
                 {:swap, expected_swap, actual_swap}
               ]
      end
    end

    test "an expected value of 0 is a wildcard for every integer property" do
      expected =
        build_server_properties(cpus: 0, cores: 0, vcpus: 0, memory: 0, swap: 0)

      actual =
        build_server_properties(cpus: 4, cores: 8, vcpus: 16, memory: 8192, swap: 4096)

      assert ServerProperties.detect_mismatches(expected, actual) == []
    end

    test "an expected value of \"*\" is a wildcard for every string property" do
      expected =
        build_server_properties(
          hostname: "*",
          machine_id: "*",
          system: "*",
          architecture: "*",
          os_family: "*",
          distribution: "*",
          distribution_release: "*",
          distribution_version: "*"
        )

      actual =
        build_server_properties(
          hostname: "host",
          machine_id: "machine-id",
          system: "system",
          architecture: "arch",
          os_family: "family",
          distribution: "distro",
          distribution_release: "release",
          distribution_version: "version"
        )

      assert ServerProperties.detect_mismatches(expected, actual) == []
    end
  end

  defp changeset(:new, data), do: changeset(:new, %ServerProperties{}, data)
  defp changeset(:update, data), do: changeset(:update, %ServerProperties{}, data)

  defp changeset(:new, properties, data),
    do: ServerProperties.new(properties, Ecto.UUID.generate(), data)

  defp changeset(:update, properties, data), do: ServerProperties.update(properties, data)

  defp build_server_properties(attrs) when is_list(attrs),
    do: build(:server_properties, Keyword.merge(@no_expected_properties, attrs))
end
