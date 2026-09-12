# App Store Connect listing — MenuTodo

Ready-to-paste text for App Store Connect. Character counts are computed against the
exact text below each field; all fields are within their limits.

## App Name (30 chars max)

```
MenuTodo - Menu Bar Todos
```

Length: 25 / 30

Note: this is the App Store listing name only. The bundle display name
(what shows under the menu bar icon and in Spotlight) stays "MenuTodo".

## Subtitle (30 chars max)

```
Local todos, Reminders sync
```

Length: 27 / 30

## Promotional Text (170 chars max)

```
A tiny todo list that lives in your menu bar. Add, check off, and reorder tasks in seconds, and sync two-way with Apple Reminders if you want them on your other devices.
```

Length: 169 / 170

## Description (4000 chars max)

```
MenuTodo is a small todo list that lives in your Mac's menu bar. It has no Dock icon and no window to manage. Click the checklist icon in the menu bar to open it, add what you need to do, and get back to work.

Type into the box at the bottom and press Return to add a todo. Click the checkbox to mark it done. Hover a row to reveal a grip handle you can drag to reorder it, or hold Option and press the Up or Down arrow while editing a row to move it up or down the list. Click the X that appears on hover to delete a row, or clear an empty row with the Delete key.

The title at the top of the list is editable. Click it and rename the list to whatever you are working on.

A footer appears when you hover the list, showing how many items are still open. It has a button to clear everything marked done, and a small menu for Settings and Quit.

In Settings you can turn on Launch at Login, and choose whether done items move to the bottom of the list automatically.

MenuTodo can also connect to one of your Apple Reminders lists. Turn this on in Settings and pick a list. From then on the two stay in sync both ways: anything you add or check off in MenuTodo shows up in Reminders, including on your iPhone and iPad, and anything you change there comes back to MenuTodo. This is entirely optional. Reminders access is only requested if you turn sync on, and you can disconnect at any time.

Everything is stored locally on your Mac. MenuTodo does not require an account and does not send your data anywhere except to Reminders when you choose to sync.
```

Length: 1554 / 4000

## Keywords (100 chars max, comma-separated)

```
todo,checklist,menu bar,tasks,reminders,to-do list,task manager,productivity,quick tasks,minimal
```

Length: 96 / 100

## What's New for 1.1.0 (4000 chars max)

This is the first App Store release, so the notes are a single short paragraph
rather than a changelog.

```
This is the first App Store release of MenuTodo. Add, check off, and reorder your todos from a small popover in the menu bar, with optional two-way sync to an Apple Reminders list of your choice.
```

Length: 195 / 4000

## Support URL

```
https://github.com/HugoPrinsloo/MenuTodo
```

## Privacy Policy URL

```
https://github.com/HugoPrinsloo/MenuTodo/blob/main/PRIVACY.md
```

(Owner/repo taken from `git remote -v`: `HugoPrinsloo/MenuTodo`.)

## Copyright

```
Copyright © 2026 Hugo Prinsloo. MIT License.
```

(Taken verbatim from `NSHumanReadableCopyright` in `MenuTodo/Info.plist`.)

## Category

Primary: Productivity

## Pricing

Free (assumption — no pricing information exists in the repo; confirm before submitting).

## Age Rating

MenuTodo has no user-generated content, no web access, and no objectionable material, so
every question in the age rating questionnaire should be answered "None":

- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Sexual Content or Nudity: None
- Profanity or Crude Humor: None
- Alcohol, Tobacco, or Drug Use: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None
- Medical/Treatment Information: None
- Gambling (Simulated): None
- Unrestricted Web Access: None
- Contests: None

## App Review notes

```
MenuTodo is a menu bar only app (LSUIElement = true): there is no Dock icon and no
main window. After launch, click the checklist icon in the menu bar to open the
app; that popover is the entire UI.

Apple Reminders access is optional. It is only requested if the user opens
Settings and turns on Reminders sync by picking a list; without that, MenuTodo
never touches Reminders. The app makes no network requests and has no accounts.
```

## Screenshots

macOS screenshots must be one of these sizes, at 16:10 aspect ratio: 1280x800,
1440x900, 2560x1600, or 2880x1800. At least 1 is required, up to 10 can be
uploaded.

Suggested shots (3 is enough to cover the app):

1. The menu bar popover open with a handful of todos, some checked off.
2. The Settings panel (General section: Launch at Login, move done to bottom).
3. The Settings panel scrolled to the Reminders section with sync connected.

To capture a shot at the exact popover bounds, use `screencapture -R x,y,w,h`
(interactive alternative: `screencapture -i`, then drag over the popover). Find
`x,y,w,h` by taking one interactive screenshot first and reading its pixel
dimensions, or by checking the popover's frame in Xcode's view debugger.

The popover itself renders much smaller than the required canvas sizes, so raw
captures need to be composited onto a full-bleed canvas at an accepted size.
`docs/screenshot.png` (the popover capture, 1006x504) has already been turned
into an upload-ready shot this way: `scripts/make-appstore-screenshot.swift`
fills a 2560x1600 canvas with the app's "Paper" background color, scales the
capture 2x with Lanczos resampling, centers it, and adds a subtle drop shadow,
writing the result to `docs/appstore/screenshot-1.png` (no alpha channel, as
App Store Connect expects). Run it with:

```
swift scripts/make-appstore-screenshot.swift
```

Repeat the same approach (new capture → same script, or a copy of it) for the
other suggested shots.
