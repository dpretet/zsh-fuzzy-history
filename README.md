# Fuzzy history

Search recent shell history without leaving Zsh. Press **Ctrl-Space**, type a
few letters, then use **Up/Down** to choose a match. **Enter** runs it;
**Escape** cancels and restores the command line as it was.

If the command line already has text, that text starts the search. With an
empty line, the menu opens without showing a history entry until you type.
The selected match is marked with `>`. Ctrl-P/Ctrl-N and Ctrl-G work as
optional alternatives for navigation and cancel.

## Install

Copy `fuzzy-history.zsh` to `~/.zsh/fuzzy-history.zsh`:

```zsh
mkdir -p ~/.zsh
cp /path/to/fuzzy-history.zsh ~/.zsh/fuzzy-history.zsh
```

Add this to `~/.zshrc` **after** your Vi/keymap setup:

```zsh
source ~/.zsh/fuzzy-history.zsh
```

Open a new shell, or source the file in the current one. The plugin does not
change ordinary Vi editing or Tab completion.

## What to expect

The search is case-insensitive and fuzzy: letters must appear in order, but
can have gaps. It rewards early positions, word starts, and consecutive
letters, penalizes gaps more heavily, and strongly favors a contiguous
occurrence of the whole query over scattered letters; newer commands win score
ties. Duplicate, multiline, and terminal-control-character entries are
excluded, as are very sparse subsequence matches that fall below the
relevance threshold.

The plugin searches up to 500 recent unique eligible commands and displays up
to 10 matches. To change the display cap, edit `_ZFH_DISPLAY_LIMIT` near the
top of the script. It builds its search list when a query first becomes
nonempty, then scores only that bounded list as you type. The scorer uses a
single subsequence pass plus a quick contiguous-match check; it avoids sorting
or rescanning the full history on each keystroke. Histories with many duplicate
or ineligible entries may take longer to fill the initial cache.

## Optional: keep routine commands out of the history file

This is separate from fuzzy search. To omit commands such as `ls` and `pwd`
when Zsh writes the history file, add the following to `~/.zshrc`:

```zsh
setopt EXTENDED_GLOB
HISTORY_IGNORE='(ls|ll|la|pwd|clear|history|exit|logout)(| *)'
```

The pattern skips an exact command name, with or without arguments (`ls -la`),
but not a longer name (`lsblk`). `HISTORY_IGNORE` affects history-file writes;
matching commands can still appear in the current shell's in-memory history
and fuzzy-search results. It does not immediately remove existing history
entries.

## Quick checks

- On an empty line, press Ctrl-Space: no history item should appear until you
  type.
- Add a few similar commands to history, then search `gts`; confirm early,
  consecutive, and word-start matches rank well.
- Use Up/Down to change selection, then Enter on a harmless command.
- Open from a partially typed line with the cursor in the middle; cancel with
  Escape and confirm the original text and cursor return.
- Repeat a command in history and confirm it appears only once.
- Try Ctrl-W/Ctrl-U and Tab while searching; confirm results refresh and Tab
  still uses the shell's configured completion.
- Search against a large loaded history and confirm typing remains responsive.

Tested on Zsh 5.9. The complete manual checklist has not been run.
