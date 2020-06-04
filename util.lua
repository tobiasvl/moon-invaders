local util = {}

function util.read_file(file)
    local rom = {}
    if love then
        if type(file) == "string" then
            file = love.filesystem.newFile(file)
        end

        local ok, err = file:open("r")

        if ok then
            local address = 0

            while (not file:isEOF()) do
                local byte, len = file:read(1)
                -- Dropped files don't seem to report EOF
                if len ~= 1 or not string.byte(byte) then
                    break
                end
                rom[address] = string.byte(byte)
                address = address + 1
            end

            file:close()
            rom.size = address
            return rom
        else
            print(err)
        end
    else
        file = io.open(file, "r")
        local address = 0
        repeat
            local b = file:read(1)
            if b then rom[address] = b:byte() end
            address = address + 1
        until not b
        rom.size = #rom
        file:close()
    end

    return rom
end

return util