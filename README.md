# You Welcome

A lightweight World of Warcraft addon that automatically replies in guild chat whenever someone posts a trigger phrase you choose — in or out of combat.

## Features

- **Custom trigger & response** — set both from an in-game panel
- **Works in and out of combat** — keeps replying even mid-fight
- **Case-insensitive matching** — `thanks` matches "Thanks!", "THANKS guys", "ty, thanks a lot"
- **Name placeholder** — use `%n` in the response to insert the sender's name
  (`You're welcome, %n!` → *You're welcome, Arthas!*)
- **Anti-spam cooldown** — 5 seconds between replies
- **Ignores your own messages**
- Settings saved between sessions, no dependencies

## Usage

| Command | Action |
|---|---|
| `/yw` or `/youwelcome` | Open / close the settings panel |
| `/yw on` | Enable auto-reply |
| `/yw off` | Disable auto-reply |

## Installation

- **WowUp:** *Get Addons → Install from URL* → paste this repository's URL
- **Manual:** download the latest zip from [Releases](../../releases) and extract the `YouWelcome` folder into
  `World of Warcraft\_retail_\Interface\AddOns\`

## License

[MIT](LICENSE)
