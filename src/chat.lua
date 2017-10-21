-- MIT License

-- Copyright (c) 2017 Datong Sun

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


local _M = {}


local CLIENTS = setmetatable({}, { __mode = 'k' })


function _M.go()
    local ctx = ngx.ctx

    local sock, err = ngx.req.socket()
    if not sock then
        ngx.log(ngx.ERR, "unable to obtain request socket: ", err)

        return
    end

    CLIENTS[ctx] = true

    _, err = sock:send("Welcome to the telnet chat demo!\nPlease provide your name: ")
    if err then
        ngx.log(ngx.ERR, "unable to read request socket: ", err)

        return ngx.exit(500)
    end

    local name
    name, err = sock:receive('*l')
    if not name then
        ngx.log(ngx.ERR, "unable to read request socket: ", err)

        return
    end

    ctx.name = name

    _, err = sock:send('Note: Type \\quit to disconnect.\n' .. name .. '> ')
    if err then
        ngx.log(ngx.ERR, "unable to read request socket: ", err)

        return ngx.exit(500)
    end

    ngx.thread.spawn(function()
        while true do
            message, err = sock:receive('*l')
            if not message then
                ngx.log(ngx.ERR, "unable to read request socket: ", err)

                return ngx.exit(500)
            end

            if message == '\\quit' then
                return ngx.exit(200)
            end

            message = ctx.name .. ': ' .. message .. '\n'

            for k, _ in pairs(CLIENTS) do
                if k ~= ctx then
                    k.message = message
                end
            end

            _, err = sock:send(name .. '> ')
            if err then
                ngx.log(ngx.ERR, "unable to read request socket: ", err)

                return ngx.exit(500)
            end
        end
    end)

    while true do
        local message = ctx.message

        if message then
            ctx.message = nil

            _, err = sock:send('\n' .. message)
            if err then
                ngx.log(ngx.ERR, "unable to write request socket: ", err)

                return
            end

            _, err = sock:send(name .. '> ')
            if err then
                ngx.log(ngx.ERR, "unable to read request socket: ", err)

                return ngx.exit(500)
            end
        end

        -- TODO: would be better to use ngx.semaphore once it is available in stream
        ngx.sleep(0.1)
    end
end


return _M
