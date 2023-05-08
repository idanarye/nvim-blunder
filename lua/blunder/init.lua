local M = {}

local util = require'blunder.util'

function M.setup(cfg)
    M.formats = cfg.formats
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

function M.sink_for_command(cmd)
    vim.fn.setqflist({}, 'r')
    local error_format = M.format_for_command(cmd)
    if error_format == nil then
        error_format = vim.o.errorformat
    end
    return function(lines)
        local qf_items = vim.fn.getqflist {
            efm = error_format,
            lines = util.clean_lines_from_pty(lines),
        }
        vim.fn.setqflist(qf_items.items, 'a')
    end
end

function M.run_in_current_window(cmd)
    local sink = M.sink_for_command(cmd)
    vim.fn.termopen(cmd, {
        on_stdout = function(_, data, _)
            sink(data)
        end,
    })
end
function M.run(cmd)
    M.create_window_for_terminal()
    M.run_in_current_window(cmd)
end

return M
