# You Welcome

A lightweight World of Warcraft addon that automatically replies in guild chat whenever someone posts one of your trigger phrases, and greets members who join or leave the guild — in or out of combat.

## Features

- **Multiple rules** — create as many trigger / response pairs as you want from an in-game panel
- **Guild join / leave messages** — separate messages when someone joins or leaves (or is kicked from) the guild, each can be turned on or off
- **Works in and out of combat** — keeps replying even mid-fight
- **Case-insensitive matching** — `thanks` matches "Thanks!", "THANKS guys", "ty, thanks a lot"
- **Name placeholder** — use `%n` in any response to insert the player's name
  (`You're welcome, %n!` → *You're welcome, Arthas!*)
- **Anti-spam cooldown** — 5 seconds between replies (chat, join and leave are tracked separately)
- **Ignores your own messages**
- If several triggers match, the first rule in the list is used
- Settings saved between sessions, no dependencies

## Usage

| Command | Action |
|---|---|
| `/yw` or `/youwelcome` | Open / close the settings panel |
| `/yw on` | Enable auto-reply |
| `/yw off` | Disable auto-reply |
| `/yw list` | Print join / leave messages and all rules in chat |

## Installation

- **WowUp:** *Get Addons → Install from URL* → paste this repository's URL
- **Manual:** download the latest zip from [Releases](../../releases) and extract the `YouWelcome` folder into
  `World of Warcraft\_retail_\Interface\AddOns\`

## License

[MIT](LICENSE)
