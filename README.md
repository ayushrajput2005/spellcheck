# Spell Checker

A local DankMaterialShell launcher plugin that checks spelling with Hunspell and offers corrections as launcher results. Spell checks run on your device; text is not sent over the network.

## Requirements

- DankMaterialShell with launcher plugin support
- Hunspell and a dictionary for the language you want to check
- `dms cl copy` or `wl-copy` for copying corrections

On Ubuntu, install Hunspell and its US English dictionary with:

```bash
sudo apt install hunspell hunspell-en-us
```

Check the installation with:

```bash
printf 'teh\n' | hunspell -a
```

## Install

Copy this plugin directory (the one containing `plugin.json`) into the DMS plugins directory:

```bash
mkdir -p ~/.config/dms/plugins/SpellChecker
cp -a /path/to/SpellChecker/. ~/.config/dms/plugins/SpellChecker/
```

Replace `/path/to/SpellChecker` with the location of this directory. In DMS Settings → Plugins, scan for plugins and enable **Spell Checker**. The manifest is `plugin.json`.

## Use

Open the launcher and enter the trigger followed by a word:

```text
sp: teh
```

Select a suggested correction and press **Enter** to copy it. **Shift+Enter** uses the launcher's paste action. If Hunspell finds no correction, the plugin shows that status; a correctly spelled word can still be selected and copied as-is.

The default trigger is `sp:` and can be changed in plugin settings. The plugin checks one line at a time (up to 128 characters). Hunspell or dictionary errors are shown in the launcher.

## Files

- `plugin.json` — DMS launcher plugin manifest and default trigger
- `SpellChecker.qml` — launcher integration, Hunspell process, and clipboard actions
- `SpellCheckerSettings.qml` — trigger setting UI
- `hunspell.js` — parser for Hunspell's `-a` output
