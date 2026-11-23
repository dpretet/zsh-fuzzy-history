# Native fuzzy history widget for Zsh.
# Source this file from an interactive Zsh configuration.

typeset -gi ZSH_FUZZY_HISTORY_LIMIT=2000
typeset -gi _ZFH_DISPLAY_LIMIT=10
typeset -ga _ZFH_CANDIDATES _ZFH_LOWER_CANDIDATES _ZFH_RESULTS
typeset -gi _ZFH_SELECTED=1
typeset -g _ZFH_ORIGINAL_BUFFER _ZFH_ORIGINAL_KEYMAP
typeset -gi _ZFH_ORIGINAL_CURSOR=0 _ZFH_CACHE_READY=0
typeset -g _ZFH_LAST_QUERY
typeset -g _ZFH_TAB_WIDGET _ZFH_CTRL_U_WIDGET _ZFH_CTRL_W_WIDGET
typeset -g _ZFH_PASTE_WIDGET _ZFH_QUOTED_INSERT_WIDGET
typeset -g _ZFH_QUOTED_INSERT_V_WIDGET

function _zfh_score {
  emulate -L zsh
  local hay=$1 needle=$2
  local -i hlen=${#hay} qlen=${#needle}
  local -i qi=1 pos=1 previous=0 current score=0 gap boundary
  local -i exact_score=0 exact_pos
  local prefix

  (( qlen )) || return 1
  while (( qi <= qlen )); do
    current=0
    while (( pos <= hlen )); do
      if [[ ${hay[$pos]} == "${needle[$qi]}" ]]; then
        current=$pos
        break
      fi
      (( pos++ ))
    done
    (( current )) || return 1

    # Greedy subsequence score: early matches and word starts help, adjacent
    # characters earn a bonus, and gaps receive a small penalty.
    boundary=0
    if [[ ${hay[$current]} == [[:alnum:]] ]] &&
       { (( current == 1 )) || [[ ${hay[$(( current - 1 ))]} != [[:alnum:]] ]]; }; then
      boundary=8
    fi
    score=$(( score + 20 + (current < 12 ? 12 - current : 0) + boundary ))
    if (( previous )); then
      gap=$(( current - previous - 1 ))
      (( gap == 0 )) && score=$(( score + 20 ))
      (( gap > 0 )) && score=$(( score - (gap * 4) ))
    fi
    previous=$current
    pos=$(( current + 1 ))
    (( qi++ ))
  done

  # Also score an exact contiguous occurrence explicitly. The greedy path may
  # have matched an earlier, scattered occurrence of the same query. A strong
  # length-scaled bonus ensures literal history matches beat unrelated
  # commands that happen to contain the query letters far apart.
  if [[ $hay == *"$needle"* ]]; then
    prefix=${hay%%"$needle"*}
    exact_pos=$(( ${#prefix} + 1 ))
    for (( qi = 1; qi <= qlen; ++qi )); do
      current=$(( exact_pos + qi - 1 ))
      boundary=0
      if [[ ${hay[$current]} == [[:alnum:]] ]] &&
         { (( current == 1 )) || [[ ${hay[$(( current - 1 ))]} != [[:alnum:]] ]]; }; then
        boundary=8
      fi
      exact_score=$(( exact_score + 20 + (current < 12 ? 12 - current : 0) + boundary ))
      (( qi > 1 )) && exact_score=$(( exact_score + 20 ))
    done
    exact_score=$(( exact_score + 40 * qlen ))
    (( exact_score > score )) && score=$exact_score
  fi

  # Keep very sparse subsequences out of the menu. A lower bound proportional
  # to query length prevents unrelated long commands from matching only by
  # chance, while compact and word-start fuzzy matches remain eligible.
  (( score >= qlen * 24 )) || return 1
  REPLY=$score
  return 0
}

function _zfh_cache {
  emulate -L zsh
  local command
  local -i event scanned=0 max_scan
  local -A seen

  _ZFH_CANDIDATES=()
  _ZFH_LOWER_CANDIDATES=()

  # Event numbers are consecutive in normal interactive history. Walk back
  # from the newest event and stop as soon as the candidate cache is full,
  # rather than sorting/processing the whole history table.
  max_scan=${HISTSIZE:-5000}
  (( max_scan < ZSH_FUZZY_HISTORY_LIMIT )) && max_scan=ZSH_FUZZY_HISTORY_LIMIT
  event=$HISTCMD
  while (( event > 0 && scanned < max_scan )); do
    command=${history[$event]-}
    (( event--, scanned++ ))
    [[ -n $command ]] || continue
    [[ $command == *[[:cntrl:]]* ]] && continue
    [[ -n ${seen[$command]-} ]] && continue
    seen[$command]=1
    _ZFH_CANDIDATES+=( "$command" )
    _ZFH_LOWER_CANDIDATES+=( "${(L)command}" )
    (( ${#_ZFH_CANDIDATES} >= ZSH_FUZZY_HISTORY_LIMIT )) && break
  done
}

function _zfh_find {
  emulate -L zsh
  local query=$1 command needle=${(L)1} score ci j k
  local -a top_commands top_scores

  _ZFH_RESULTS=()
  _ZFH_SELECTED=1
  [[ -n $query ]] || return 0

  for (( ci = 1; ci <= ${#_ZFH_CANDIDATES}; ++ci )); do
    command=${_ZFH_CANDIDATES[ci]}
    _zfh_score "${_ZFH_LOWER_CANDIDATES[ci]}" "$needle" || continue
    score=$REPLY

    # Candidates are newest-first, so strict comparisons preserve the newer
    # command whenever relevance scores tie. Only the display limit is retained.
    if (( ${#top_commands} < _ZFH_DISPLAY_LIMIT )); then
      top_commands+=( "$command" )
      top_scores+=( "$score" )
      j=${#top_commands}
    else
      (( score > top_scores[-1] )) || continue
      top_commands[-1]=$command
      top_scores[-1]=$score
      j=${#top_commands}
    fi

    while (( j > 1 && top_scores[j] > top_scores[j - 1] )); do
      k=$(( j - 1 ))
      command=${top_commands[j]}
      top_commands[j]=${top_commands[k]}
      top_commands[k]=$command
      score=${top_scores[j]}
      top_scores[j]=${top_scores[k]}
      top_scores[k]=$score
      (( j-- ))
    done
  done

  _ZFH_RESULTS=( "${top_commands[@]}" )
}

function _zfh_render {
  emulate -L zsh
  local query=$1 count=${#_ZFH_RESULTS} i

  if [[ -z $query ]]; then
    POSTDISPLAY=' [fuzzy history: type to search; Enter does nothing yet]'
    return
  fi
  if (( count == 0 )); then
    POSTDISPLAY=' [no matches]'
    return
  fi

  POSTDISPLAY=$'\n'
  for (( i = 1; i <= count; ++i )); do
    if (( i == _ZFH_SELECTED )); then
      POSTDISPLAY+="> "
    else
      POSTDISPLAY+="  "
    fi
    POSTDISPLAY+="${(V)_ZFH_RESULTS[i]}"
    (( i < count )) && POSTDISPLAY+=$'\n'
  done
  return 0
}

function _zfh_query_changed {
  emulate -L zsh
  if [[ -n $BUFFER ]] && (( ! _ZFH_CACHE_READY )); then
    _zfh_cache
    _ZFH_CACHE_READY=1
  fi
  _zfh_find "$BUFFER"
  _ZFH_LAST_QUERY=$BUFFER
  _zfh_render "$BUFFER"
}

function _zfh_widget {
  emulate -L zsh
  _ZFH_ORIGINAL_BUFFER=$BUFFER
  _ZFH_ORIGINAL_CURSOR=$CURSOR
  _ZFH_ORIGINAL_KEYMAP=$KEYMAP
  _ZFH_CACHE_READY=0

  if [[ -n $BUFFER ]]; then
    _zfh_cache
    _ZFH_CACHE_READY=1
  fi
  _zfh_find "$BUFFER"
  _ZFH_LAST_QUERY=$BUFFER
  zle -K _zfh_map
  _zfh_render "$BUFFER"
}

function _zfh_insert {
  zle .self-insert
  _zfh_query_changed
}

function _zfh_backspace {
  zle .backward-delete-char
  _zfh_query_changed
}

function _zfh_delete {
  zle .delete-char
  _zfh_query_changed
}

function _zfh_tab {
  zle "$_ZFH_TAB_WIDGET"
  _zfh_query_changed
}

function _zfh_ctrl_u {
  zle "$_ZFH_CTRL_U_WIDGET"
  _zfh_query_changed
}

function _zfh_ctrl_w {
  zle "$_ZFH_CTRL_W_WIDGET"
  _zfh_query_changed
}

function _zfh_paste {
  zle "$_ZFH_PASTE_WIDGET"
  _zfh_query_changed
}

function _zfh_quoted_insert {
  zle "$_ZFH_QUOTED_INSERT_WIDGET"
  _zfh_query_changed
}

function _zfh_quoted_insert_v {
  zle "$_ZFH_QUOTED_INSERT_V_WIDGET"
  _zfh_query_changed
}

function _zfh_up {
  (( ${#_ZFH_RESULTS} )) && _ZFH_SELECTED=$(( _ZFH_SELECTED == 1 ? ${#_ZFH_RESULTS} : _ZFH_SELECTED - 1 ))
  _zfh_render "$BUFFER"
}

function _zfh_down {
  (( ${#_ZFH_RESULTS} )) && _ZFH_SELECTED=$(( _ZFH_SELECTED == ${#_ZFH_RESULTS} ? 1 : _ZFH_SELECTED + 1 ))
  _zfh_render "$BUFFER"
}

function _zfh_cancel {
  BUFFER=$_ZFH_ORIGINAL_BUFFER
  CURSOR=$_ZFH_ORIGINAL_CURSOR
  zle -K "$_ZFH_ORIGINAL_KEYMAP"
  POSTDISPLAY=''
}

function _zfh_accept {
  local count=${#_ZFH_RESULTS}
  # Some inherited editing/completion widgets may alter BUFFER. Refresh as a
  # final guard so Enter can never accept a result for an obsolete query.
  [[ $BUFFER == "$_ZFH_LAST_QUERY" ]] || _zfh_query_changed
  count=${#_ZFH_RESULTS}
  if [[ -n $BUFFER ]] && (( count && _ZFH_SELECTED >= 1 && _ZFH_SELECTED <= count )); then
    BUFFER=${_ZFH_RESULTS[_ZFH_SELECTED]}
    CURSOR=${#BUFFER}
    zle -K "$_ZFH_ORIGINAL_KEYMAP"
    POSTDISPLAY=''
    zle .accept-line
  fi
}

zle -N _zfh_widget
zle -N _zfh_insert
zle -N _zfh_backspace
zle -N _zfh_delete
zle -N _zfh_up
zle -N _zfh_down
zle -N _zfh_cancel
zle -N _zfh_accept
zle -N _zfh_tab
zle -N _zfh_ctrl_u
zle -N _zfh_ctrl_w
zle -N _zfh_paste
zle -N _zfh_quoted_insert
zle -N _zfh_quoted_insert_v

function _zfh_capture_widget {
  local keymap=$1 key=$2 binding
  binding=$(bindkey -M "$keymap" "$key") || return 1
  REPLY=${binding##* }
}

_zfh_capture_widget viins '^I'; _ZFH_TAB_WIDGET=$REPLY
_zfh_capture_widget viins '^U'; _ZFH_CTRL_U_WIDGET=$REPLY
_zfh_capture_widget viins '^W'; _ZFH_CTRL_W_WIDGET=$REPLY
_zfh_capture_widget viins '^[[200~'; _ZFH_PASTE_WIDGET=$REPLY
_zfh_capture_widget viins '^Q'; _ZFH_QUOTED_INSERT_WIDGET=$REPLY
_zfh_capture_widget viins '^V'; _ZFH_QUOTED_INSERT_V_WIDGET=$REPLY

# The menu runs as ordinary ZLE input, not a blocking `read` loop. Its
# temporary keymap copies viins and changes only menu-specific bindings.
bindkey -N _zfh_map viins
bindkey -M _zfh_map -R ' -~' _zfh_insert
bindkey -M _zfh_map '^?' _zfh_backspace
bindkey -M _zfh_map '^H' _zfh_backspace
bindkey -M _zfh_map '^[[3~' _zfh_delete
bindkey -M _zfh_map '^M' _zfh_accept
bindkey -M _zfh_map '^J' _zfh_accept
bindkey -M _zfh_map '^G' _zfh_cancel
bindkey -M _zfh_map '^[' _zfh_cancel
bindkey -M _zfh_map '^P' _zfh_up
bindkey -M _zfh_map '^N' _zfh_down
bindkey -M _zfh_map '^[[A' _zfh_up
bindkey -M _zfh_map '^[[B' _zfh_down
bindkey -M _zfh_map '^[OA' _zfh_up
bindkey -M _zfh_map '^[OB' _zfh_down
bindkey -M _zfh_map '^I' _zfh_tab
bindkey -M _zfh_map '^U' _zfh_ctrl_u
bindkey -M _zfh_map '^W' _zfh_ctrl_w
bindkey -M _zfh_map '^[[200~' _zfh_paste
bindkey -M _zfh_map '^Q' _zfh_quoted_insert
bindkey -M _zfh_map '^V' _zfh_quoted_insert_v

# In the requested vi-insert setup, main is linked to viins. Binding only
# this map leaves normal vi command-mode and all other bindings untouched.
bindkey -M viins '^@' _zfh_widget
