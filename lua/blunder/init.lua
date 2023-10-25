---@mod blunder Blunder - Populate the quickfix from interactive terminal jobs
local M = {}

---@brief [[
---Neovim's |:make| command can parse the output from a shell command to
---generate entries for the |quickfix| list. |:make| uses the non-interactive
---shell, which means that:
---* The Neovim UI is blocked while the command is running.
---* Some compilers or build tools offer nice PTY features like colors and
---  progress bars. These don't work with |:make|.
---* No stdin (so it can't, for example, parse exceptions from REPLs)
---* The command output cannot stay open when Neovim's event loop is back. The
---  data may still be accessible from the quickfix list, but it would be
---  processed.
---
---Blunder allows using Neovim's builtin interactive |terminal| for the same
---purpose. This means that the build commands can fully utilize the PTY, and
---that the terminal buffer remains open and the text in it can be searched and
---scrolled using Neovim's full power.
---@brief ]]

---@tag blunder-installation
---@brief [[
---Install "idanarye/nvim-blunder" using your favorite plugin manager, and in
---your |init.lua| call:
--->
--- require'blunder'.setup {
---     -- Default settings
---     formats = {},
---     fallback_format = ..., -- reducted - its very long
---     commands_prefix = 'B',
--- }
---<
---This will configure Blunder register the commands |:Bmake| and |:Brun|.
---@brief ]]

---@tag blunder-usage
---@brief [[
---* |:Bmake| works like |:make| but uses a terminal.
---* |blunder.make| - Lua API version of |:Bmake|.
---* |:Brun| - run any shell command in a terminal, and deduce the desired
---            error format from |blunder.formats|.
---* |blunder.run| - Lua API version of |:Brun|. Also supports manually setting
---                  the error format.
---@brief ]]

local util = require'blunder.util'

local function gen_cmd_completion_function(prefix)
    return function(_, cmdline, loc)
        vim.cmd.messages('clear')
        local pattern_to_complete = cmdline:sub(1, loc)
        local _, really_start_from = pattern_to_complete:find('%s*%S+')
        local real_pattern = prefix .. pattern_to_complete:sub(really_start_from + 1)
        return vim.fn.getcompletion(real_pattern, 'cmdline')
    end
end

---@tag blunder.formats
---@brief [[
---When setting up blunder in |init.lua|, you can set up formats for various
---compilers and build commands:
--->
--- require'blunder'.setup {
---     formats = {
---         -- These formats are copied from the builtin runtime/compiler/*.vim files
---         go = table.concat({
---             [=[%-G# %.%#]=],
---             [=[%A%f:%l:%c: %m]=],
---             [=[%A%f:%l: %m]=],
---             [=[%C%*\s%m]=],
---             [=[%-G%.%#]=],
---         }, ','),
---         perl = table.concat({
---             [=[%-G%.%#had compilation errors.]=],
---             [=[%-G%.%#syntax OK]=],
---             [=[%m at %f line %l.]=],
---             [=[%+A%.%# at %f line %l\]=],
---             [=[%.%#]=],
---             [=[%+C%.%#]=],
---         }, ','),
---     },
--- },
---<
---Then, invoking |:Brun| with "go" or "perl" as the program will use the
---registered error format. Note that invoking |:Brun| with some unregistered
---program will use the fallback format (which defaults to Neovim's default
---'errorformat', which is quite big), and that |:Bmake| does not use these
---formats - it always uses the 'errorformat' of the buffer it was called from.
---@brief ]]
M.formats = {}

-- This is a default fallback format, generated from the default errorformat
-- you get in `nvim -u NONE`.
M.fallback_format = table.concat({
    [=[%*[^"]"%f"%*\D%l: %m]=],
    [=["%f"%*\D%l: %m]=],
    [=[%-G%f:%l: (Each undeclared identifier is reported only once]=],
    [=[%-G%f:%l: for each function it appears in.)]=],
    [=[%-GIn file included from %f:%l:%c:]=],
    [=[%-GIn file included from %f:%l:%c\,]=],
    [=[%-GIn file included from %f:%l:%c]=],
    [=[%-GIn file included from %f:%l]=],
    [=[%-G%*[ ]from %f:%l:%c]=],
    [=[%-G%*[ ]from %f:%l:]=],
    [=[%-G%*[ ]from %f:%l\,]=],
    [=[%-G%*[ ]from %f:%l]=],
    [=[%f:%l:%c:%m]=],
    [=[%f(%l):%m]=],
    [=[%f:%l:%m]=],
    [=["%f"\,line %l%*\D%c%*[^ ] %m]=],
    [=[%D%*\a[%*\d]: Entering directory %*[`']%f']=],
    [=[%X%*\a[%*\d]: Leaving directory %*[`']%f']=],
    [=[%D%*\a: Entering directory %*[`']%f']=],
    [=[%X%*\a: Leaving directory %*[`']%f']=],
    [=[%DMaking %*\a in %f]=],
    [=[%f|%l| %m]=],
}, ',')

---@class BlunderConfig
---@field formats { [string]: string } Formats for specific commands (based on the executable without the arguments).
---@field fallback_format? string The format to use if the command does not match any specific format.
---@field commands_prefix? string|false Defaults to 'B'.

---Configure Blunder and create the Vim commands.
---@param cfg BlunderConfig
function M.setup(cfg)
    if cfg.formats then
        M.formats = cfg.formats
    end
    if cfg.fallback_format then
        M.fallback_format = cfg.fallback_format
    end

    if cfg.commands_prefix ~= false then
        local commands_prefix = cfg.commands_prefix or 'B'

        ---@tag :Brun
        ---@brief [[
        ---The `:Brun` command runs a shell command in a new terminal window,
        ---parsing its output into the quickfix list using an error format
        ---deduced from the command itself (see |blunder.formats|)
        ---@brief ]]
        vim.api.nvim_create_user_command(commands_prefix .. 'run', function(opts)
            require'blunder'.run(opts.args)
        end, {nargs = 1, complete = gen_cmd_completion_function('!')})

        ---@tag :Bmake
        ---@brief [[
        ---The `:Bmake` runs the 'makeprg' shell command in a terminal, parsing
        ---its output into the quickfix list using Neovim's normal
        ---'errorformat' option.
        ---@brief ]]
        vim.api.nvim_create_user_command(commands_prefix .. 'make', function(opts)
            require'blunder'.make(opts.args)
        end, {nargs = '?', complete = gen_cmd_completion_function('make')})
    end
end

---Create a new window that tries to replicate the |:!| / |:make| UX but with terminal jobs.
---
---* When the terminal window is closed, the focus will return (if possible) to
---  the original window from which this function was invoked.
---* Automatically goes into insert mode inside the new window.
---* Does not actually start the terminal.
function M.create_window_for_terminal()
    local prev_win_id = vim.fn.win_getid(vim.fn.winnr())
    vim.cmd'botright 20new'
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd('WinEnter', {
        buffer = bufnr,
        callback = function()
            prev_win_id = vim.fn.win_getid(vim.fn.winnr('#'))
        end,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
        buffer = bufnr,
        callback = function()
            vim.fn.win_gotoid(prev_win_id)
        end,
    })
    vim.cmd.startinsert()
end

---Pick the error format suitable for the given command
---@param cmd string|string[]
---@return string
function M.format_for_command(cmd)
    if type(cmd) == 'string' then
        cmd = vim.split(cmd, '%s')
    end
    local format = M.formats[cmd[1]]
    if format == nil then
        format = M.fallback_format
        if format == nil then
            error('Blunder knows no error format for ' .. vim.inspect(cmd) .. ', and no fallback_format is configured')
        end
    end
    return format
end

---@class BlunderSinkOpts
---@field efm? string An error format for the sink
---@field cmd? string|string[] A command to derive the error format from

---Start a new empty quickfix list, and return a function that can be used to update it.
---
---The function should be called with the data passed by Neovim to as the
---second argument for on_stdout/on_stderr when creating a terminal.
---@param opts BlunderSinkOpts
---@return function(data: string[])
function M.sink(opts)
    vim.fn.setqflist({}, 'r')
    local error_format
    if opts.efm ~= nil then
        error_format = opts.efm
    elseif opts.cmd ~= nil then
        error_format = M.format_for_command(opts.cmd)
    else
        error_format = M.fallback_format
        if error_format == nil then
            error('Sink has neither `efm` nor `cmd`, and no fallback_format is configured')
        end
    end
    local squash_invalids = {}
    return function(lines)
        local qf_items = vim.fn.getqflist {
            efm = error_format,
            lines = util.clean_lines_from_pty(lines),
        }.items or {}
        if squash_invalids then
            local first_valid_idx = nil
            for idx, item in ipairs(qf_items) do
                if item.valid == 1 then
                    first_valid_idx = idx
                    break
                end
            end
            if first_valid_idx then
                first_valid_idx = first_valid_idx + #squash_invalids
                vim.list_extend(squash_invalids, qf_items)
                qf_items = squash_invalids
                squash_invalids= nil
                local invalid_item = qf_items[1]
                local valid_item = qf_items[first_valid_idx]
                do
                    local tmp = invalid_item.text
                    invalid_item.text = valid_item.text
                    valid_item.text = tmp
                end
                qf_items[1] = valid_item
                qf_items[first_valid_idx] = invalid_item
            else
                vim.list_extend(squash_invalids, qf_items)
                return
            end
        end
        vim.fn.setqflist(qf_items, 'a')
    end
end

---Runs the command in a new terminal job using the given sink.
---
---This is a low(ish) level function, exported for thoes who know what they are
---doing. Casual users should prefer |blunder.run| or |blunder.make|, which
---also create the window and the sink, or |blunder.for_channelot| for
---integration with Channelot.
---@param cmd string|string[] A command to run
---@param sink function(data: string[])
function M.impl(cmd, sink)
    vim.fn.termopen(cmd, {
        on_stdout = function(_, data, _)
            sink(data)
        end,
    })
end

---@class BlunderRunOpts
---@field efm? string An error format

---Generate a sink for running a command.
---
---|blunder.run| uses this behind the scenes.
---@param cmd string|string[] The command to prepare the sink for.
---@param opts? BlunderRunOpts
function M.sink_for_run_command(cmd, opts)
    if opts == nil then
        opts = {}
    end
    return M.sink{
        cmd = cmd,
        efm = opts.efm,
    }
end

---Run a terminal job in a new window, parsing the output into a quickfix list.
---
---The error format will be determined by the command, unless overridden in the
---opts argument: `require'blunder'.run('gcc main.c', { efm = '...' })`
---@param cmd string|string[] A command to run
---@param opts? BlunderRunOpts
function M.run(cmd, opts)
    local sink = M.sink_for_run_command(cmd, opts)
    M.create_window_for_terminal()
    M.impl(cmd, sink)
end

---Similar to |blunder.run|, but uses the |:make| configuration.
---
---* The command will run using the 'makeprg' of the active buffer. The content
---  of the makeprg_args will be appended to it.
---* The output will parsed using the 'errorformat' of the active buffer.
---@param makeprg_args? string|string[] Arguments for makeprg
function M.make(makeprg_args)
    local cmd
    if makeprg_args == nil then
        cmd = vim.fn.expandcmd(vim.o.makeprg)
    elseif type(makeprg_args) == 'string' then
        cmd = vim.fn.expandcmd(vim.o.makeprg .. ' ' .. makeprg_args)
    else
        cmd = table.concat({
            vim.fn.expandcmd(vim.o.makeprg),
            unpack(vim.tbl_map(vim.fn.shellescape, makeprg_args)),
        }, ' ')
    end

    local sink = M.sink { efm = vim.o.errorformat }
    M.create_window_for_terminal()
    M.impl(cmd, sink)
end

---Pass to |ChannelotJob:using| to parse output from a Channelot job into the quickfix list.
---@param opts? BlunderSinkOpts
function M.for_channelot(opts)
    if opts ~= nil and opts.job_id and opts.command then
        -- Assume opts is the job
        return M.for_channelot()(opts)
    end
    return function(job)
        vim.validate {
            job={job, function(j)
                if type(j) ~= 'table' then
                    return false
                end
                return type(j.job_id) == 'number' and j.command ~= nil
            end, 'ChannelotJob'}
        }
        if opts == nil then
            opts = {}
        end
        if opts.cmd == nil then
            opts = vim.tbl_extend('error', { cmd = job.command }, opts)
        end
        local sink = M.sink(opts)
        local function handler(_, data)
            sink(data)
        end
        if job.pty then
            table.insert(job.callbacks.stdout, handler)
        else
            table.insert(job.callbacks.stderr, handler)
        end
    end
end

return M
