defmodule ArchiDep.DigestProjectTest do
  use ExUnit.Case, async: true

  # The `digest` project digests the assets of the production image, and the
  # cache manifest its Phoenix writes is read by the application's Phoenix (see
  # the `Dockerfile`). Updating Phoenix here without updating it there would
  # leave the two to drift apart.
  @app_lock Path.expand("../../mix.lock", __DIR__)
  @digest_lock Path.expand("../../../digest/mix.lock", __DIR__)

  test "the digest project locks the same Phoenix as the application" do
    assert phoenix_locked_by(@digest_lock) == phoenix_locked_by(@app_lock)
  end

  defp phoenix_locked_by(lock_file) do
    {lock, _binding} =
      lock_file
      |> File.read!()
      |> Code.string_to_quoted!(emit_warnings: false, file: lock_file)
      |> Code.eval_quoted()

    Map.fetch!(lock, :phoenix)
  end
end
