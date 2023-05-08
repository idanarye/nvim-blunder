local M = {}

local PATTERNS_TO_CLEAN = {
    -- Copied from https://stackoverflow.com/a/55324681/794380
    '\x1b%[%d+;%d+;%d+;%d+;%d+m',
    '\x1b%[%d+;%d+;%d+;%d+m',
    '\x1b%[%d+;%d+;%d+m',
    '\x1b%[%d+;%d+m',
    '\x1b%[%d+m',

    -- These were missing from that SO answer
    '\x1b%[K',
    '\x1b%[m',

    -- PTY also spits these:
    '\r',
}

function M.clean_lines_from_pty(text)
    if type(text) == 'string' then
        for _, pattern_to_clean in ipairs(PATTERNS_TO_CLEAN) do
            text = text:gsub(pattern_to_clean, '')
        end
        return text
    elseif type(text) == 'table' then
        local result = {}
        for i, line in ipairs(text) do
            result[i] = M.clean_lines_from_pty(line)
        end
        return result
    else
        error('Cannot clear ANSI codes from ' .. type(text))
    end
end

return M
