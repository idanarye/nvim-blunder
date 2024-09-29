# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/idanarye/nvim-blunder/compare/v0.1.0...v0.2.0) (2024-09-29)


### Features

* Add `:Bexecute` ([c212670](https://github.com/idanarye/nvim-blunder/commit/c2126701d76752e9f039cb79efe4cca51f5259b7))
* Add option for `create_window_for_terminal` to use existing buffer ([a8eff55](https://github.com/idanarye/nvim-blunder/commit/a8eff556d36c942da728aafdb2775e226f3cc4e8))

## 0.1.0 (2023-10-25)


### Features
- Run commands in interactive terminal and parse outout into quickfix list.
- Create and configure a window with good UX for running terminal commands.
- `:Bmake` command which mimics `:make`.
- `:Brun` command which deduced the error format from the command.
- Ability to manually set the error format when invoking the Lua API.
- [Channelot](https://github.com/idanarye/nvim-channelot) integration.
