defmodule ArchiDep.Emoji do
  @moduledoc """
  The emoji the site is written with, and the only place that decides what one
  looks like.

  The course material and the application show the same emoji in the same places
  — the 📚 of a "more information" note is written as a shortcode in a chapter
  and drawn by a component in the dashboard — so both take them from this one
  registry instead of each spelling them out. The registry is **closed**: an
  emoji that is not in it is not one of the site's, which is what keeps the
  vocabulary a small set of pictures that mean something (an exclamation mark
  says "do this", a boom says "here is what goes wrong") rather than whatever
  each page felt like.

  An emoji is drawn as an **image** rather than left as a character so that it
  is the same picture on every operating system, in a PDF printed by a headless
  browser, and in a build served with no network of its own. The files are
  Twemoji SVGs kept in `theme/emoji` and served from `/assets/emoji`; the README
  there says where they come from and how to add one.

  This module is the only place in the application allowed to write an emoji
  character, and `img/3` the only place that writes the markup one is shown as.
  """

  @enforce_keys [:name, :character, :codepoints]
  defstruct [:name, :character, :codepoints]

  @typedoc """
  An emoji of the site: the name it is written by, the character it stands for,
  and the codepoints naming the file it is drawn from.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          character: String.t(),
          codepoints: String.t()
        }

  # The vocabulary itself. A name is the shortcode the course material writes
  # and the name a component asks for; the character is what the emoji is, and
  # what a reader copying the page out of their browser gets back.
  @characters %{
    "beer" => "🍺",
    "beers" => "🍻",
    "blue_heart" => "💙",
    "book" => "📖",
    "books" => "📚",
    "boom" => "💥",
    "checkered_flag" => "🏁",
    "clap" => "👏",
    "clapper" => "🎬",
    "classical_building" => "🏛️",
    "coffee" => "☕",
    "confetti_ball" => "🎊",
    "crossed_swords" => "⚔️",
    "dizzy" => "💫",
    "exclamation" => "❗",
    "face_with_spiral_eyes" => "😵‍💫",
    "gem" => "💎",
    "hammer_and_wrench" => "🛠️",
    "house" => "🏠",
    "memo" => "📝",
    "money_with_wings" => "💸",
    "question" => "❓",
    "rocket" => "🚀",
    "scroll" => "📜",
    "shrug" => "🤷",
    "sob" => "😭",
    "space_invader" => "👾",
    "sparkles" => "✨",
    "star2" => "🌟",
    "sunglasses" => "😎",
    "tada" => "🎉",
    "thinking" => "🤔",
    "thumbsup" => "👍",
    "trophy" => "🏆"
  }

  # Twemoji names a file after the codepoints of the emoji it draws, leaving out
  # the variation selector that only says the character is meant as a picture.
  # Deriving the name rather than writing it down is what keeps a file and the
  # character it is claimed to draw from ever disagreeing.
  @codepoints Map.new(@characters, fn {name, character} ->
                {name,
                 character
                 |> String.to_charlist()
                 |> Enum.reject(&(&1 == 0xFE0F))
                 |> Enum.map_join("-", fn codepoint ->
                   codepoint |> Integer.to_string(16) |> String.downcase()
                 end)}
              end)

  @names_by_character Map.new(@characters, fn {name, character} -> {character, name} end)

  @names @characters |> Map.keys() |> Enum.sort()

  # What an emoji looks like in text. The site's own emoji are matched as the
  # exact characters they are, longest first, so that one written with another
  # inside it — a face with spiral eyes is a face joined to a dizzy — is
  # recognised as the whole it is rather than as its parts.
  #
  # Anything else is matched only where it cannot be anything but a picture: a
  # character of the pictographic blocks, or a symbol asked to be drawn as one
  # by a variation selector. A check mark, a sharp sign and the arrows are
  # punctuation as often as decoration, and are deliberately left out.
  @character_pattern @characters
                     |> Map.values()
                     |> Enum.sort_by(&byte_size/1, :desc)
                     |> Enum.map(&Regex.escape/1)
                     |> Enum.concat([
                       "[\\x{1F000}-\\x{1FAFF}]\\x{FE0F}?",
                       "[\\x{2190}-\\x{2BFF}]\\x{FE0F}"
                     ])
                     |> Enum.join("|")
                     |> Regex.compile!("u")

  @doc """
  Look an emoji up by the name the course material and the application write it
  by.

      iex> Emoji.fetch("books")
      {:ok, %Emoji{name: "books", character: "📚", codepoints: "1f4da"}}

      iex> Emoji.fetch("unicorn")
      :error
  """
  @spec fetch(String.t()) :: {:ok, t()} | :error
  def fetch(name) when is_binary(name) do
    case Map.fetch(@characters, name) do
      {:ok, character} ->
        {:ok,
         %__MODULE__{
           name: name,
           character: character,
           codepoints: Map.fetch!(@codepoints, name)
         }}

      :error ->
        :error
    end
  end

  @doc """
  Look an emoji up by name, raising an `ArgumentError` when the site has no such
  emoji.

  Use this where the name is written in the code rather than in a document: a
  component asking for the emoji it is built around cannot carry on without it,
  and the mistake is a typo to fix rather than a fact about the content.

      iex> Emoji.fetch!("tada")
      %Emoji{name: "tada", character: "🎉", codepoints: "1f389"}
  """
  @spec fetch!(String.t()) :: t()
  def fetch!(name) when is_binary(name) do
    case fetch(name) do
      {:ok, emoji} -> emoji
      :error -> raise ArgumentError, "The site has no emoji named #{inspect(name)}"
    end
  end

  @doc """
  Look an emoji up by the character it stands for, which is how a document that
  types the emoji itself rather than its name is understood.

      iex> Emoji.fetch_by_character("🎉")
      {:ok, %Emoji{name: "tada", character: "🎉", codepoints: "1f389"}}
  """
  @spec fetch_by_character(String.t()) :: {:ok, t()} | :error
  def fetch_by_character(character) when is_binary(character) do
    case Map.fetch(@names_by_character, character) do
      {:ok, name} -> fetch(name)
      :error -> :error
    end
  end

  @doc """
  The names of every emoji of the site, in alphabetical order.
  """
  @spec names :: [String.t()]
  def names, do: @names

  @doc """
  How an emoji is written where it is to be drawn later: the shortcode a page
  writes, which anything rendering into a page writes too.

      iex> Emoji.shortcode(Emoji.fetch!("gem"))
      ":gem:"
  """
  @spec shortcode(t()) :: String.t()
  def shortcode(%__MODULE__{name: name}), do: ":#{name}:"

  @doc """
  What an emoji looks like in text, as a regular expression matching one.

  Rewriting the emoji of a text takes a single pass over it, because an emoji of
  the site is shown as markup that names the character it draws: replacing them
  one after another would find the second one inside what the first left behind.
  """
  @spec pattern :: Regex.t()
  def pattern, do: @character_pattern

  @doc """
  The emoji written in a text, in the order they first appear.

      iex> Emoji.characters_in("Yay! 🎉 Now brew some ☕ and think 🤔🤔")
      ["🎉", "☕", "🤔"]

      iex> Emoji.characters_in("2 + 2 ≠ 5 ✓")
      []
  """
  @spec characters_in(String.t()) :: [String.t()]
  def characters_in(text) when is_binary(text),
    do: @character_pattern |> Regex.scan(text) |> Enum.map(&hd/1) |> Enum.uniq()

  @doc """
  The emoji written in a text that are not the site's, which is what makes the
  vocabulary a rule rather than an offer.

      iex> Emoji.unregistered_characters_in("Have a 🍺 on the 🛼")
      ["🛼"]
  """
  @spec unregistered_characters_in(String.t()) :: [String.t()]
  def unregistered_characters_in(text) when is_binary(text),
    do: text |> characters_in() |> Enum.reject(&is_map_key(@names_by_character, &1))

  @doc """
  The name of the file an emoji is drawn from.

      iex> Emoji.file_name(Emoji.fetch!("classical_building"))
      "1f3db.svg"
  """
  @spec file_name(t()) :: String.t()
  def file_name(%__MODULE__{codepoints: codepoints}), do: "#{codepoints}.svg"

  @doc """
  The path an emoji's file is served at, as the course material site refers to a
  global asset.

      iex> Emoji.asset_path(Emoji.fetch!("boom"))
      "/assets/emoji/1f4a5.svg"
  """
  @spec asset_path(t()) :: String.t()
  def asset_path(%__MODULE__{} = emoji), do: "/assets/emoji/#{file_name(emoji)}"

  @doc """
  The markup an emoji is shown as, given the URL its file is served at by the
  build doing the showing.

  The alternative text is the character itself: a reader who cannot see the
  image is told which emoji it is by their own software, and a reader copying
  the page out of their browser gets the emoji back rather than a description of
  it. Pass `:alt` where the emoji says something the surrounding text does not,
  and `:class` to size it.

      iex> Emoji.img(Emoji.fetch!("books"), "/assets/emoji/1f4da.svg")
      ~s(<img class="emoji" src="/assets/emoji/1f4da.svg" alt="📚" />)

      iex> Emoji.img(Emoji.fetch!("trophy"), "/assets/emoji/1f3c6.svg", alt: "Graded", class: "size-4")
      ~s(<img class="emoji size-4" src="/assets/emoji/1f3c6.svg" alt="Graded" />)
  """
  @spec img(t(), String.t()) :: String.t()
  @spec img(t(), String.t(), keyword()) :: String.t()
  def img(%__MODULE__{character: character}, url, opts \\ []) when is_binary(url) do
    class = Enum.join(["emoji" | List.wrap(Keyword.get(opts, :class))], " ")
    alt = Keyword.get(opts, :alt, character)
    ~s(<img class="#{class}" src="#{url}" alt="#{alt}" />)
  end
end
