defmodule ArchiDep.CourseSite.Archives.OverridesTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Archives.Overrides

  doctest ArchiDep.CourseSite.Archives.Overrides

  describe "from_yaml/1" do
    test "reads the pages every edition declares something about" do
      assert Overrides.from_yaml(%{
               2025 => %{
                 "/course/104-ssh/" => "/course/106-secure-shell/",
                 "/cheatsheets/unix/" => "gone"
               },
               2026 => %{"/course/301-http/" => "/course/305-http/"}
             }) ==
               {:ok,
                %Overrides{
                  editions: %{
                    "2025" => %{
                      "/course/104-ssh/" => {:page, "/course/106-secure-shell/"},
                      "/cheatsheets/unix/" => :gone
                    },
                    "2026" => %{"/course/301-http/" => {:page, "/course/305-http/"}}
                  }
                }}
    end

    test "reads an edition that declares nothing" do
      assert Overrides.from_yaml(%{2025 => %{}}) ==
               {:ok, %Overrides{editions: %{"2025" => %{}}}}
    end

    test "reads a file holding no document at all" do
      assert Overrides.from_yaml(nil) == {:ok, %Overrides{editions: %{}}}
    end

    test "refuses overrides that are not a map of editions" do
      assert Overrides.from_yaml(["2025"]) ==
               {:error, [{:malformed_overrides, ~s|["2025"] is not a map of editions|}]}
    end

    test "refuses an edition that is not a year" do
      assert Overrides.from_yaml(%{"last-year" => %{}}) ==
               {:error, [{:malformed_edition, "last-year"}]}
    end

    test "refuses an edition written both as a number and as a string" do
      assert Overrides.from_yaml(%{2025 => %{}, "2025" => %{}}) ==
               {:error, [{:duplicate_edition, "2025"}]}
    end

    test "refuses an edition declaring something that is not a map of pages" do
      assert Overrides.from_yaml(%{2025 => ["/course/104-ssh/"]}) ==
               {:error, [{:malformed_entries, "2025", ["/course/104-ssh/"]}]}
    end

    test "refuses a page that is not named by a path" do
      assert Overrides.from_yaml(%{2025 => %{"course/104-ssh/" => "gone"}}) ==
               {:error, [{:malformed_source, "2025", "course/104-ssh/"}]}
    end

    test "refuses a target that is neither a path nor gone" do
      assert Overrides.from_yaml(%{2025 => %{"/course/104-ssh/" => "maybe"}}) ==
               {:error, [{:malformed_target, "2025", "/course/104-ssh/", "maybe"}]}
    end

    test "reports every mistake of the file rather than the first" do
      assert Overrides.from_yaml(%{
               "whenever" => %{},
               2025 => %{"/a/" => "elsewhere", "b/" => "gone"},
               2026 => ["/c/"]
             }) ==
               {:error,
                [
                  {:malformed_target, "2025", "/a/", "elsewhere"},
                  {:malformed_source, "2025", "b/"},
                  {:malformed_entries, "2026", ["/c/"]},
                  {:malformed_edition, "whenever"}
                ]}
    end
  end

  describe "editions/1" do
    test "lists the editions declared, in order" do
      {:ok, overrides} = Overrides.from_yaml(%{2026 => %{}, 2025 => %{}})

      assert Overrides.editions(overrides) == ["2025", "2026"]
    end

    test "lists nothing when nothing is declared" do
      assert Overrides.editions(%Overrides{editions: %{}}) == []
    end
  end

  describe "entries/2" do
    test "returns what an edition declares" do
      {:ok, overrides} = Overrides.from_yaml(%{2025 => %{"/course/104-ssh/" => "gone"}})

      assert Overrides.entries(overrides, "2025") == %{"/course/104-ssh/" => :gone}
    end

    test "returns nothing for an edition declaring nothing" do
      assert Overrides.entries(%Overrides{editions: %{}}, "2025") == %{}
    end
  end

  describe "format_error/1" do
    test "describes overrides that are not a map of editions" do
      assert Overrides.format_error({:malformed_overrides, "nil is not a map of editions"}) ==
               "The archive overrides are invalid: nil is not a map of editions"
    end

    test "describes an edition that is not a year" do
      assert Overrides.format_error({:malformed_edition, "last-year"}) ==
               ~s|The archive overrides declare "last-year", which is not a year|
    end

    test "describes an edition declared twice" do
      assert Overrides.format_error({:duplicate_edition, "2025"}) ==
               "The archive overrides declare edition 2025 twice"
    end

    test "describes an edition declaring something that is not a map of pages" do
      assert Overrides.format_error({:malformed_entries, "2025", ["/a/"]}) ==
               ~s|Edition 2025 declares ["/a/"] rather than a map of pages|
    end

    test "describes a page that is not named by a path" do
      assert Overrides.format_error({:malformed_source, "2025", "course/104-ssh/"}) ==
               ~s|Edition 2025 declares "course/104-ssh/", which is not the path of a page|
    end

    test "describes a target that is neither a path nor gone" do
      assert Overrides.format_error({:malformed_target, "2025", "/course/104-ssh/", "maybe"}) ==
               ~s|Edition 2025 sends "/course/104-ssh/" to "maybe", which is neither the path of a page nor "gone"|
    end
  end
end
