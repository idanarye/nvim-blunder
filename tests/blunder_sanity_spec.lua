describe('Blunder sanity', function()
    local blunder = require'blunder'

    it('Brun works', function()
        blunder.formats.echo = [=[%o:%l:%c %m]=]
        vim.cmd.Brun('echo mymodule:42:7 something something')
        blunder.formats.echo = nil

        WaitForTerminalClose()
        local qf = vim.tbl_filter(function(entry)
            return entry.valid == 1
        end, vim.fn.getqflist())
        assert(#qf == 1)
        assert(qf[1].module == 'mymodule')
        assert(qf[1].lnum == 42)
        assert(qf[1].col == 7)
        assert(qf[1].text == 'something something')
    end)

    it('Bmake works', function()
        vim.cmd.new()
        vim.bo.makeprg = 'echo'
        vim.bo.errorformat = [=[%o:%l:%c %m]=]
        vim.cmd.Bmake('mymodule:42:7 something something')

        WaitForTerminalClose()
        local qf = vim.tbl_filter(function(entry)
            return entry.valid == 1
        end, vim.fn.getqflist())
        assert(#qf == 1)
        assert(qf[1].module == 'mymodule')
        assert(qf[1].lnum == 42)
        assert(qf[1].col == 7)
        assert(qf[1].text == 'something something')
    end)

    it('blunder.run with custom error format', function()
        blunder.run({'echo', 'mymodule:42:7', 'something something'}, {
            efm = [=[%o:%l:%c %m]=]
        })

        WaitForTerminalClose()
        local qf = vim.tbl_filter(function(entry)
            return entry.valid == 1
        end, vim.fn.getqflist())
        assert(#qf == 1)
        assert(qf[1].module == 'mymodule')
        assert(qf[1].lnum == 42)
        assert(qf[1].col == 7)
        assert(qf[1].text == 'something something')
    end)

    for _, c in ipairs{
        {cmd = 'Brun', modifies_qf = true },
        {cmd = 'Bexecute', modifies_qf = false },
    }
    do
        local test_text = c.cmd .. ' does'
        if not c.modifies_qf then
            test_text = test_text .. ' not'
        end
        test_text = test_text .. ' modify the quickfix list'
        it(test_text, function()
            local function get_qf_text_only()
                return vim.iter(vim.fn.getqflist())
                :map(function(item)
                    return item.text
                end)
                :totable()
            end
            vim.fn.setqflist({{text = 'test'}})
            assert.are.same(get_qf_text_only(), {'test'})
            vim.cmd[c.cmd]('ls')
            if c.modifies_qf then
                assert.are.same(get_qf_text_only(), {})
            else
                assert.are.same(get_qf_text_only(), {'test'})
            end
        end)
    end
end)

