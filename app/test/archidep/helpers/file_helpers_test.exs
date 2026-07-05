defmodule ArchiDep.Helpers.FileHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Helpers.FileHelpers

  # The digest embeds each file's absolute path (the wildcard yields absolute
  # paths under the per-run `tmp_dir`), so the exact bytes vary per run and
  # cannot be pinned to a golden constant. The meaningful contract is instead a
  # content-addressed digest: identical for the same tree, different for any
  # change to a file's content, name, or the set of files. Each assertion below
  # compares two whole digests by equality.
  describe "hash_files_in_directory!/1" do
    @tag :tmp_dir
    test "is deterministic for the same directory tree", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "a.txt"), "hello")
      File.write!(Path.join(tmp_dir, "b.txt"), "world")

      assert FileHelpers.hash_files_in_directory!(tmp_dir) ==
               FileHelpers.hash_files_in_directory!(tmp_dir)
    end

    @tag :tmp_dir
    test "changes when a file's content changes", %{tmp_dir: tmp_dir} do
      file = Path.join(tmp_dir, "a.txt")
      File.write!(file, "hello")
      before = FileHelpers.hash_files_in_directory!(tmp_dir)

      File.write!(file, "goodbye")

      refute FileHelpers.hash_files_in_directory!(tmp_dir) == before
    end

    @tag :tmp_dir
    test "changes when a file is added", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "a.txt"), "hello")
      before = FileHelpers.hash_files_in_directory!(tmp_dir)

      File.write!(Path.join(tmp_dir, "b.txt"), "world")

      refute FileHelpers.hash_files_in_directory!(tmp_dir) == before
    end

    @tag :tmp_dir
    test "ignores non-regular entries such as empty subdirectories", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "a.txt"), "hello")
      before = FileHelpers.hash_files_in_directory!(tmp_dir)

      File.mkdir!(Path.join(tmp_dir, "empty_subdir"))

      assert FileHelpers.hash_files_in_directory!(tmp_dir) == before
    end
  end
end
