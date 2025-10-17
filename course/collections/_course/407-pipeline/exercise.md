---
title: Unix Pipeline
cloud_server: details
excerpt_separator: <!-- more -->
---

This exercise teaches you how to use Unix command pipelines and stream redirections to analyze and manipulate text files efficiently.

{% callout type: exercise %}

You can do this exercise locally (in the macOS Terminal or the WSL on Windows)
or on your cloud server through SSH. Both will work.

{% endcallout %}

<!-- more -->

## :exclamation: Setup

Download the exercise file to your computer with the following command:

```bash
$> curl -L https://git.io/fAjRa > rainbow.txt
```

Display the file:

```bash
$> cat rainbow.txt
Somewhere over the rainbow
...
```

## :exclamation: The exercise

Use command pipelines and stream redirections to:

- Count the number of lines and characters in the text
- Print the lines of the text containing the word `rainbow`
- Do the same but without any duplicates
- Print the second word of each line in the text
- Compress the text and save it to `rainbow.txt.gz`
- Count the number of times the letter `e` is used (case-insensitive)
- Count the number of times the word `the` is used (case-insensitive)
- Answer the question: what are the five most used words in the
  text (case-insensitive) and how many times are they used?

## :gem: Example

For example, the following command counts the number of words in the text:

```bash
$> cat rainbow.txt | wc -w
255
```

## :gem: Your tools

Here are a few commands you might find useful for the exercise. They all operate
on the data received from their standard input stream, and print the result on
their standard output stream, so they can be piped into each other:

| Command                             | Description                                                                                  |
| :---------------------------------- | :------------------------------------------------------------------------------------------- |
| `cut -d ' ' -f <n>`                 | Select word in column `<n>` of each line (using one space as the delimiter)                  |
| `fold -w 1`                         | Print one character by line                                                                  |
| `grep [-i] <letterOrWord>`          | Select only lines that contain a given letter or word, e.g. `grep foo` (`-i` to ignore case) |
| `grep "^<text>$"`                   | Select only lines that contain this exact text (e.g. `grep "^foo$"`)                         |
| `gzip -c`                           | Compress data                                                                                |
| `sort [-n]`                         | Sort lines alphabetically (`-n` to sort numerically)                                         |
| `tr '[:upper:]' '[:lower:]'`        | Convert all uppercase characters to lowercase                                                |
| `tr -s '[[:punct:][:space:]]' '\n'` | Split by word                                                                                |
| `uniq [-c]`                         | Filter out repeated lines (`-c` also counts them)                                            |
| `wc [-l] [-w] [-m]`                 | Count lines, words or characters                                                             |

{% note type: tip %}
Remember that if you want to know more about any of these commands or
their options, all you have to do is type `man <command>`, i.e. `man cut`.
{% endnote %}

## :checkered_flag: What have I done?

You have seen that text can be passed through several programs and transformed
at each step to obtain the final result you want.

In essence, you have constructed complex programs by piping simpler programs
together, combining them into a more powerful whole. You have applied the Unix
philosophy.
