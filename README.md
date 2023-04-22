# muren.nvim

Neovim plugin for doing multiple search and replace with ease.

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

See [examples] below for some screencasts of how this looks like with `muren`.

## Features
* TODO

## Installation
TODO

## Usage
TODO

## Configuration
TODO

## Showcase
TODO

## Trivia
TODO
