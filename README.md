# muren.nvim

Neovim plugin for doing multiple search and replace with ease.

:warning: This plugins is in its early days so feel free to open issues if you stumble on issues, have ideas or are missing some things to configure.

## What does this plugin do

Sometimes you may want to do some number of search-and-replacements that follow a certain structure.
Lets say you have some variables named `a_0`, `a_1` and `a_2` but you instead want to rename them to `x`, `y` and `z`.
Using builtin methods there are a few ways to do that (and maybe more which I don't know):

* Do the replacements one by one manually.
* Do the first replacement and then edit the command in the command-line window (`q:`).
* Come up with some complex regex.

All of which I find somewhat cumbersome.

With `muren` ui, you get two buffers where you can enter a sequence of patterns in the left one (one per line)
in the right buffer enter the replacements in the corresponding row. For example it would look something like:
```
a_0 | x
a_1 | y
a_2 | z
```
where you can use all your vim-skills to populate the buffers (eg `<C-v>`, `<C-a>` etc etc).

See [examples](#showcase) below for some screencasts of how this looks like with `muren`.

## Features
* Define and apply multiple replacements.
* Toggle between recursive and non-recursive replacements (eg to sway names), see [showcases](#showcase).
* Interactively changes options, including which buffer to apply to.
* Preview changes.
* Keep patterns and options when toggling ui.

## Installation
Use your favorite plugin manager, eg with `lazy.nvim`:
```lua
{
  'AckslD/muren.nvim',
  config = true,
}
```

## Usage
By default the following commands are created:

* `MurenToggle`: Toggle the UI.
* `MurenOpen`: Open the UI.
* `MurenClose`: Open the UI.
* `MurenFresh`: Open the UI fresh, ie reset all settings and buffers.
* `MurenUnique`: Open the UI populating the patterns with all unique matches of the last search.

Pass `create_commands = false` to `require('muren').setup` to not create them.

You can also access this using lua as the following functions:

* `require('muren.api').toggle_ui`
* `require('muren.api').open_ui`
* `require('muren.api').close_ui`
* `require('muren.api').open_fresh_ui`
* `require('muren.api').open_unique_ui`

## Configuration
Pass settings to `require('muren').setup`. The current defaults are:
```lua
{
  -- general
  create_commands = true,
  -- default togglable options
  recursive = false,
  all_on_line = true,
  preview = true,
  -- ui sizes
  patterns_width = 30,
  patterns_height = 10,
  options_width = 15,
  preview_height = 12,
  -- options order in ui
  order = {
    'buffer',
    'recursive',
    'all_on_line',
    'preview',
  },
  -- highlights used for options ui
  hl = {
    options = {
      on = '@string',
      off = '@variable.builtin',
    },
  },
}
```

## Showcase
### Basic usage
Basic usage replacing variables `a_0`, `a_1` and `a_2` to `x`, `y` and `z`:

https://user-images.githubusercontent.com/23341710/233819100-6e18e39e-37bc-42b4-82b4-237fa4eeee25.mp4

### Swapping things
Using non-recursive replacements one can swap variables with ease since they are first replaced to temporary placeholders. Toggle the option (see below) to see the difference.

https://user-images.githubusercontent.com/23341710/233819106-8d08cacd-2adc-467c-a784-6f5e59ef6ca1.mp4

### Pick options interactively
You can change some options interactively while previewing your changes in the UI.

https://user-images.githubusercontent.com/23341710/233819114-406dcbe0-ec25-45fc-9240-84ba926a6c5e.mp4

Note in particular how things change in the preview.

### Populate with unique previuous search matches
`:MurenUnique` might initially seem like a random command but something I find very useful. What it does is it finds all the matches of your last search and populates the unique set of these in the patterns pane of the UI. You can them replace all of them in some way but importantly you can do this differently for each unique match.

https://user-images.githubusercontent.com/23341710/233819184-df374312-8947-4b50-baf9-f3136b4d344e.mp4

## TODO

- [ ] Store history of batches replacements and have a telescope picker to chose between them, previewing the list of patterns and replacements.
- [ ] Possibly calculate the preview asynchronously in case it makes the UI sluggish?

## Etymology

Here are two explanations for the name of the plugin, choose the one you like the most:
* `muren` stands for "MUltiple REplacements in Neovim".
* _muren_ is the swedish word for "the wall" and refers to the border between the patterns-buffer and the replacements-buffer.
