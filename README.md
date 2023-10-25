[![CI Status](https://github.com/idanarye/nvim-blunder/workflows/CI/badge.svg)](https://github.com/idanarye/blunder/actions)

INTRODUCTION
============

Neovim's `:make` command can parse the output from a shell command to generate entries for the quickfix list. `:make` uses the non-interactive shell, which means that:
* The Neovim UI is blocked while the command is running.
* Some compilers or build tools offer nice PTY features like colors and progress bars. These don't work with `:make`.
* No stdin (so it can't, for example, parse exceptions from REPLs)
* The command output cannot stay open when Neovim's event loop is back. The data may still be accessible from the quickfix list, but it would be processed.

Blunder allows using Neovim's builtin interactive terminal for the same purpose. This means that the build commands can fully utilize the PTY, and that the terminal buffer remains open and the text in it can be searched and scrolled using Neovim's full power.

INSTALLATION
============

Install `idanarye/nvim-blunder` using your favorite plugin manager, and in your `init.lua` call:
```lua
require'blunder'.setup {
    -- Default settings
    formats = {},
    fallback_format = ..., -- reducted - its very long
    commands_prefix = 'B',
}
```
This will configure Blunder register the commands |:Bmake| and |:Brun|.

USAGE
=====

* `:Bmake` works like |:make| but uses a terminal.
* `blunder.make` - Lua API version of `:Bmake`.
* `:Brun` - run any shell command in a terminal, and deduce the desired error format from `blunder.formats`.
* `blunder.run` - Lua API version of `:Brun`. Also supports manually setting the error format.

USAGE WITH CHANNELOT (AND MOONICIPAL)
=====================================

[Channelot](https://github.com/idanarye/nvim-channelot) is a plugin that streamlines running shell commands in a Neovim terminal. It needs to be run in a coroutine - or in a [Moonicipal](https://github.com/idanarye/nvim-moonicipal) task, since Moonicipal runs its tasks in coroutines, and Channelot was made to work well with Moonicipal.

`ChannelotJob` has a `using` method, which Blunder's `for_channelot` can use to parse the output of a the job into the quickfix list. To combine it inside a Moonicipal task, add something like this to the Moonicipal tasks file:

```lua
local blunder = require'blunder'
local channelot = require'channelot'

function T:run()
    -- This will create a window for running the shell commands.
    blunder.create_window_for_terminal()

    -- This will create a terminal in the window, prompt the user to close it
    -- once all the jobs finish, and handle the `check` method calls inside it
    -- by properly displaying in the terminal the exit status of a failed shell
    -- command.
    channelot.terminal():with(function(t)
        -- When running gcc, use Blunder to parse the output.
        t:job{'gcc', 'main.c'}:using(blunder.for_channelot):check()
        -- ./a.out runs without blunder, so its output won't get parsed into
        -- the quickfix list.
        t:job{'./a.out'}:check()
    end)
end
```

CONTRIBUTION GUIDELINES
=======================

* If your contribution can be reasonably tested with automation tests, add tests.
* Documentation comments must be compatible with both [Sumneko Language Server](https://github.com/sumneko/lua-language-server/wiki/Annotations) and [lemmy-help](https://github.com/numToStr/lemmy-help/blob/master/emmylua.md). If you do something that changes the documentation, please run `make docs` to update the vimdoc.
* Update the changelog according to the [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) format.
