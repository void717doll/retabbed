# differences from tabbed 0.9

retabbed imports the tabbed component from `/home/mia/suckless/jOS/tabbed`,
as checked on 2026-10-28 at jOS commit
`1a448c7880af1d769b427addab45231330f50ebe`. its tracked tabbed files had no
local changes. the comparison baseline is the supplied, unmodified
`/home/mia/tabbed-0.9` source, recorded in the first commit of this repo.
runtime code, defaults, and the three existing test sources are copied
without changes from that jOS snapshot. binaries and generated `config.h`
are excluded.

these are local changes found by comparing the source trees. the jOS history
contains them in one component import, so individual upstream patch names
or authors cannot be established from that history.

## existing-window grouping

- `tabbed.c`: `-G windowid` enables grouping of existing top-level X11
  windows. one or two initial ids are accepted, in decimal or hexadecimal;
  further windows can be attached through the message protocol below.
  a command cannot be supplied in this mode.
- group mode uses the instance name `dwm-tabs` and class `tabbed`, closes
  the container when its last client leaves, and disables automatic
  command spawning/refilling. it exits if no initial window can be attached.
- `attachwindow()` rejects zero ids, the root, the container, duplicate
  clients, missing windows, override-redirect windows, and windows whose
  parent is not the root.
- grouped clients enter the X save set before reparenting, allowing the
  server to preserve them if the container connection disappears.
- `detachwindow()` removes input selection and passive key grabs, reparents
  the application to the desktop at the group's content position, removes
  it from the save set, maps it, and removes it from the tab list.
- `_TABBED_GROUP` is a 32-bit `ClientMessage` sent to the container.
  `data.l[0] = 0` attaches the window in `data.l[1]`;
  `data.l[0] = 1` detaches the selected tab. if one tab remains after a
  detach request, it is detached too, dissolving the two-window group.

## mouse behavior

- upstream 0.9 already supported left-click selection, middle-click close,
  and wheel navigation. these actions are retained rather than introduced
  by this fork.
- `tabat()` provides shared hit testing for clicks and hover. coordinates
  outside the bar and hidden tabs are excluded, as is the left overflow
  label when present. the right overflow label has no tab hit target.
- pointer motion, entry, and leave events update hover coordinates. moving
  between tabs redraws the bar; motion within the same tab avoids a redraw.
- group mode highlights the tab beneath the pointer without selecting it.
  leaving the bar clears the highlight. ordinary command-based mode keeps
  its original normal/selected/urgent colors.
- there is no added tab dragging or click action for the overflow labels.
  moving a whole group with super+drag is supplied by jOS's dwm.

## close and cleanup fixes

- a `WM_DELETE_WINDOW` request in group mode closes the selected application
  instead of immediately shutting down the container and releasing all tabs.
  this also applies to the final tab: the container waits for the client to
  leave, then exits through its last-client policy.
- the existing close helper first sends `WM_DELETE_WINDOW` when supported.
  another close request for that client, or a client without that protocol,
  uses `XKillClient`. this fallback behavior already existed in 0.9;
  killing an X connection may affect other windows owned by that connection.
- ordinary containers retain their existing close policy, including `-k`.
- cleanup walks clients backwards so removing one cannot skip the next.
  group cleanup detaches surviving clients instead of closing them; ordinary
  cleanup retains the close/reparent path.
- the imported manual claimed that closing a group returns all applications
  to the desktop. that sentence is corrected here: explicit detach and group
  cleanup return survivors; a normal close request targets the selected tab.

## titles, narrow bars, and appearance

- `config.def.h` changes the font from `monospace:size=9` to
  `monospace:size=14`, selected background from `#555555` to `#666666`,
  and adds hover colors `#888888` / `#ffffff`.
- the bar height is at least 30 pixels, or the font height plus two pixels
  when larger. the target tab width remains 200 pixels.
- `visibletabs()` always leaves room for at least one tab when clients exist,
  even below the target tab width. the selected tab stays in the visible
  range. overflow labels are omitted when they would fill the entire bar.
- every redraw clears cached tab edges first, preventing invisible tabs
  from retaining stale click targets. zero-sized bars are skipped.
- resizing redraws the bar immediately. empty-bar title strings returned
  by `XFetchName` are freed after drawing.
- title propagation itself is inherited from 0.9: `focus()` gives the
  container the selected client's title; `updatetitle()` refreshes it when
  the selected client's title changes, preferring `_NET_WM_NAME` and falling
  back to `WM_NAME`. `xsettitle()` writes both properties.
- the related jOS dwm code is outside this repo. its `createtitlebar()`
  avoids adding a second title frame to class `tabbed`, and its `drawbar()`
  omits `dwm-tabs` groups from the desktop bar's window-title list. this
  leaves the application titles in tabbed's own tab strip without duplication.
  those dwm changes are required to reproduce that desktop presentation.
- the inherited tiny-window behavior temporarily hides the strip when the
  container height cannot fit it, then restores it when there is room.
  the bar is not forced visible at every possible window height.

## resize and XEmbed fixes

- a container resize updates every embedded client, including inactive tabs,
  instead of only the selected client.
- `resize()` queries server geometry and skips unchanged configurations.
  it repairs actual drift in x/y, width/height, and border width, rather than
  trusting a remembered request. clients stay at `(0, bar height)` with no
  border and fill the content area.
- configuration requests and synthetic notifications include x and border
  width as well as y, width, and height. missing clients are skipped when
  their attributes cannot be read.
- `XEMBED_EMBEDDED_NOTIFY` is sent to the embedded client rather than the
  root window. `XWithdrawWindow` uses the active screen rather than screen 0.
- bar drawing uses `XFlush` in place of `XSync`, and focus no longer adds
  another synchronous round trip after drawing.

## keyboard differences

| action | supplied 0.9 | retabbed |
| --- | --- | --- |
| next tab | ctrl+shift+l | ctrl+shift+l, ctrl+tab, ctrl+PageDown, super+shift+Right |
| previous tab | ctrl+shift+h | ctrl+shift+h, ctrl+shift+tab, ctrl+PageUp, super+shift+Left |
| previous selection | ctrl+tab | no default binding; ctrl+tab now cycles forward |
| spawn another command | ctrl+shift+Return | ctrl+shift+Return, ctrl+shift+t |
| close selected tab | ctrl+q | ctrl+F4, ctrl+shift+w |

tab reordering, numbered selection, dmenu selection, urgency controls, and
F11 are unchanged. spawn shortcuts require command-based mode; group mode
has no application command to repeat.

jOS's dwm binds super+shift+equal to group compatible visible windows and
super+shift+minus to detach the selected tab. those bindings and the code
that chooses windows live in `dwm/config.def.h` and `dwm/desktop.c`, not here.
other window managers can launch `tabbed -G ...` or send `_TABBED_GROUP`
messages themselves.

## build, packaging, and documentation

- jOS adds `make check` with address and undefined-behavior sanitizers and
  linker wrappers for X11 calls. it also adds `.gitignore` entries for
  objects, executables, generated configuration, and release archives.
- `config.h` now depends on `config.def.h`. a newer default file replaces
  the generated file, so persistent customizations belong in `config.def.h`.
- this repo restores a standalone `README`, adds this patch inventory, and
  installs both documents with `LICENSE`. the source archive includes the
  three existing test sources so `make check` also works after extraction.
- the manual documents `-G`, mouse controls, new shortcuts, grouping versus
  detach/close behavior, and the generated configuration rule. the obsolete
  README reference to `config.mk` is removed; paths and flags are set through
  the `Makefile` and make variables.
- `LICENSE`, `arg.h`, `xembed.c`, and `xembed.1` are unchanged from the
  supplied 0.9 tree. executable names, X11 class, and version remain unchanged.

## verification

`make check` builds both tools and runs the imported suites:

- `tests/tabs.c`: widths from 1 to 900 pixels with up to eight tabs,
  selected-tab visibility, valid drawing bounds, stale hit targets, and
  group hover without selection changes.
- `tests/render.c`: redundant resize suppression, geometry drift repair,
  border removal, client configuration requests, and size restoration.
- `tests/close.c`: selected-tab and final-tab close requests, repeated close
  fallback, no-protocol fallback, empty group exit, and ordinary close policy.

these tests mock X11 calls. they do not establish live window-manager
behavior, save-set recovery, attachment/detachment, visual appearance, or
title propagation in a desktop session. title persistence and real mouse
interaction still need a live X11 check. no new runtime tests were added
for this import.
