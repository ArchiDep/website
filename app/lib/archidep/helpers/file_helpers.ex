defmodule ArchiDep.Helpers.FileHelpers do
  @moduledoc """
  Helper functions for working with files.
  """

  @spec hash_files_in_directory!(Path.t()) :: binary()
  def hash_files_in_directory!(dir),
    do:
      :crypto.hash(
        :sha256,
        dir
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.sort()
        |> Enum.map(
          &Task.async(fn ->
            case File.stat!(&1) do
              %File.Stat{type: :regular} -> [&1, hash_file!(&1)]
              _other -> []
            end
          end)
        )
        |> Task.await_many()
        |> Enum.flat_map(& &1)
        |> Enum.join("\0")
      )

  defp hash_file!(path),
    do:
      path
      |> File.stream!(2048)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
end
