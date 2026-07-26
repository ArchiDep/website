defmodule ArchiDep.EmojiTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Emoji

  doctest ArchiDep.Emoji

  @emoji_files Path.expand("../../../theme/emoji", __DIR__)
  @lib Path.expand("../../lib", __DIR__)
  @registry Path.join(@lib, "archidep/emoji.ex")

  describe "fetch!/1" do
    test "refuses a name the site has no emoji for" do
      assert_raise ArgumentError, ~s(The site has no emoji named "unicorn"), fn ->
        Emoji.fetch!("unicorn")
      end
    end
  end

  describe "fetch_by_character/1" do
    test "does not recognise a character that is not one of the site's emoji" do
      assert Emoji.fetch_by_character("🛼") == :error
    end
  end

  describe "the vocabulary" do
    test "every emoji of the site is drawn from a file, and every file draws one" do
      drawn_from =
        Emoji.names()
        |> Enum.map(&(&1 |> Emoji.fetch!() |> Emoji.file_name()))
        |> Enum.sort()

      assert @emoji_files
             |> File.ls!()
             |> Enum.filter(&(Path.extname(&1) == ".svg"))
             |> Enum.sort() ==
               drawn_from
    end

    test "the registry is the only place the application writes an emoji" do
      written =
        @lib
        |> Path.join("**/*.{ex,exs,heex}")
        |> Path.wildcard()
        |> List.delete(@registry)
        |> Enum.flat_map(fn path ->
          case path |> File.read!() |> Emoji.characters_in() do
            [] -> []
            characters -> [{Path.relative_to(path, @lib), characters}]
          end
        end)

      assert written == []
    end
  end
end
