vim.o.shada = ''

vim.opt.runtimepath:append { '.' }
vim.opt.runtimepath:append { '../plenary.nvim' }

require'blunder'.setup {
}

function EnsureSingleWindow()
    local wins = vim.api.nvim_list_wins()
    vim.cmd.new()
    for _, winnr in ipairs(wins) do
        vim.api.nvim_win_close(winnr, true)
    end
end

function Sleep(duration)
    local co = coroutine.running()
    vim.defer_fn(function()
        coroutine.resume(co)
    end, duration)
    coroutine.yield()
end

function WaitFor(timeout_secs, pred, sleep_ms)
    local init_time = vim.loop.uptime()
    local last_time = init_time + timeout_secs
    while true do
        local iteration_time = vim.loop.uptime()
        local result = {pred()}
        if result[1] then
            return unpack(result)
        end
        if last_time < iteration_time then
            error('Took too long (' .. (iteration_time - init_time) .. ' seconds)')
        end
        Sleep(sleep_ms or 10)
    end
end

function WaitForTerminalClose()
    local co = coroutine.running()
    vim.api.nvim_create_autocmd('TermClose', {
        buffer = 0,
        once = true,
        callback = function(event)
            coroutine.resume(co, event)
        end,
    })
    return coroutine.yield()
end
