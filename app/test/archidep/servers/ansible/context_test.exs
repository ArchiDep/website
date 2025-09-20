defmodule ArchiDep.Servers.Ansible.ContextTest do
  use ExUnit.Case, async: true

  import ArchiDep.Servers.Ansible.Context, only: [digest_ansible_variables: 1]

  test "compute the digest of ansible variables" do
    value = %{
      "foo" => [1, :qux, 2, true, 3.14, "string"],
      "bar" => %{baz: true, corge: false},
      "grault" => nil,
      "alice" => ["bob", "dave", "carol"]
    }

    normalized =
      Enum.join(
        [
          "alice",
          "bob",
          "dave",
          "carol",
          "bar",
          "bar.baz",
          "true",
          "bar.corge",
          "false",
          "foo",
          "1",
          "qux",
          "2",
          "true",
          "3.14",
          "string",
          "grault",
          "\0"
        ],
        "\0"
      )

    assert digest_ansible_variables(value) == :crypto.hash(:sha256, normalized)
  end
end
