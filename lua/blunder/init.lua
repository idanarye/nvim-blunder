local M = {}

local util = require'blunder.util'

function M.setup(cfg)
    M.formats = cfg.formats
    vim.api.nvim_create_user_command('Brun', function(opts)
        require'blunder'.run(opts.args)
    end, {
        nargs = 1,
        complete = 'shellcmd',
    })
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

---@class BlunderRunOpts
---@field fmt? string An error format

---@param cmd string|string[] A command to run
---@param opts? BlunderSinkOpts
function M.run_in_current_window(cmd, opts)
    if opts == nil then
        opts = {}
    end
    local sink = M.sink{
        cmd = cmd,
        fmt = opts.fmt,
    }
    vim.fn.termopen(cmd, {
        on_stdout = function(_, data, _)
            sink(data)
        end,
    })
end

---@param cmd string|string[] A command to run
---@param opts? BlunderSinkOpts
function M.run(cmd, opts)
    M.create_window_for_terminal()
    M.run_in_current_window(cmd, opts)
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
