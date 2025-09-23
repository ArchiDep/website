defmodule ArchiDep.Servers.Schemas.ServerPropertiesTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.ServersFactory
  alias ArchiDep.Servers.Schemas.ServerProperties

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

  defp build_server_properties(attrs) when is_list(attrs),
    do: build(:server_properties, Keyword.merge(@no_expected_properties, attrs))
end
