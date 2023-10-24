local M = {}

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

---@class BlunderConfig
---@field formats { [string]: string }
---@field commands_prefix? string|false

---@param cfg BlunderConfig
function M.setup(cfg)
    M.formats = cfg.formats

    if cfg.commands_prefix ~= false then
        local commands_prefix = cfg.commands_prefix or 'B'

        vim.api.nvim_create_user_command(commands_prefix .. 'run', function(opts)
            require'blunder'.run(opts.args)
        end, {nargs = 1, complete = gen_cmd_completion_function('!')})
        vim.api.nvim_create_user_command(commands_prefix .. 'make', function(opts)
            require'blunder'.make(opts.args)
        end, {nargs = '?', complete = gen_cmd_completion_function('make')})
    end
end

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

function M.format_for_command(cmd)
    if type(cmd) == 'string' then
        cmd = vim.split(cmd, '%s')
    end
    return M.formats[cmd[1]]
end

---@class BlunderSinkOpts
---@field fmt? string An error format for the sink
---@field cmd? string|string[] A command to derive the error format from

---@param opts BlunderSinkOpts
function M.sink(opts)
    vim.fn.setqflist({}, 'r')
    local error_format
    if opts.fmt ~= nil then
        error_format = opts.fmt
    elseif opts.cmd ~= nil then
        error_format = M.format_for_command(opts.cmd)
        if error_format == nil then
            error_format = vim.o.errorformat
        end
    else
        error_format = vim.o.errorformat
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
---@field fmt? string An error format

function M.sink_for_run_command(cmd, opts)
    if opts == nil then
        opts = {}
    end
    return M.sink{
        cmd = cmd,
        fmt = opts.fmt,
    }
end

---@param cmd string|string[] A command to run
---@param opts? BlunderRunOpts
function M.run(cmd, opts)
    local sink = M.sink_for_run_command(cmd, opts)
    M.create_window_for_terminal()
    M.impl(cmd, sink)
end

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

    local sink = M.sink { fmt = vim.o.errorformat }
    M.create_window_for_terminal()
    M.impl(cmd, sink)
end

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
