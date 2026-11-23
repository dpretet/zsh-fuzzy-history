Act as a senior Zsh developer. Design and implement a native fuzzy-history
search widget.

## Environment

- Use the installed Zsh; my normal editing mode is Vi insert mode, with `main`
  linked to `viins`.
- Use only Zsh built-ins, bundled modules, and functions distributed with Zsh.
- Do not use third-party tools or plugins, including fzf, Atuin, or
  zsh-autocomplete.
- Preserve my standard completion configuration and ordinary Vi editing.

## Widget behavior

- Ctrl-Space is the only shortcut that opens the history search.
- With an empty command line, open the menu without showing or selecting a
  history entry. Existing command-line text is the initial query.
- Update results as the query is typed or deleted. Search the current shell's
  loaded history.
- Match case-insensitive subsequences. Favor matches near the start of a
  command and consecutive characters; prefer newer entries on score ties.
- Deduplicate commands, automatically select the best match, and display no
  more than 10 results below the query, marking the selected entry with `>`.
  `_ZFH_DISPLAY_LIMIT` should control this limit.
- Up/Down changes the selection (Ctrl-P/Ctrl-N may also be supported). Enter
  executes the selected command; with an empty query or no matches, Enter must
  execute nothing.
- Escape restores the original command line, cursor position, and keymap.
  Ctrl-G may also cancel.
- Support single-line history; exclude multiline entries and entries with
  terminal control characters.

## Display and responsiveness

- Use ZLE-managed display (such as `POSTDISPLAY`) for the result list. Do not
  print menu text directly to the terminal or use a blocking terminal-read
  loop; the prompt and screen must redraw without overlap or line movement.
- Use a temporary keymap so ordinary Vi editing and Tab completion are
  unchanged. Preserve unrelated bindings and make repeated sourcing safe.
- Set `ZSH_FUZZY_HISTORY_LIMIT=500` near the top of the script. It is the
  maximum number of recent unique eligible commands searched.
- Avoid sorting or rescanning the full history on each keystroke. Explain the
  matching approach and its responsiveness tradeoffs briefly.

## History filtering

- Do not add command-ignore or history-storage filtering to the widget.
- In the README, briefly explain how a user can optionally filter routine
  commands from future history using built-in Zsh facilities, such as the
  `zshaddhistory` hook. Make clear that this is separate from fuzzy search
  and does not rewrite existing history.

## Delivery

- Provide the complete script as `~/.zsh/fuzzy-history.zsh`, the source line
  needed in `.zshrc`, and brief user-focused installation and usage guidance.
- Keep the README practical and concise. Include quick manual checks for empty
  search, fuzzy ranking, navigation, execution, cancellation, existing prompt
  text, deduplication, and responsiveness.
- State what was actually tested and the Zsh version used; do not claim
  validation on versions that were not tested.
