# Emoji

The site's emoji, as SVG files served from `/assets/emoji`.

Both halves of the project — the static course material and the dynamic
application — draw their emoji from these files, so that the same emoji looks
the same everywhere it appears. Which emoji exist is decided in
[`ArchiDep.Emoji`](../../app/lib/archidep/emoji.ex), the closed registry that
maps a name such as `books` to the file it is drawn from; nothing renders an
emoji any other way.

## Attribution

These graphics are [Twemoji](https://github.com/jdecked/twemoji) by the Twemoji
contributors, copied unmodified from tag `v17.0.3`, and licensed under
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Adding an emoji

The file name is the emoji's Unicode codepoints in lowercase hexadecimal,
separated by hyphens and without the variation selector `fe0f` — the naming
Twemoji itself uses, so that a file can be traced back to its source and
refreshed.

1. Download
   `https://raw.githubusercontent.com/jdecked/twemoji/v17.0.3/assets/svg/<codepoints>.svg`
   into this directory.
2. Add the emoji to `ArchiDep.Emoji`, whose test asserts that every registered
   emoji has a file here and that every file here is registered.
