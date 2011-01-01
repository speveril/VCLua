-- Does preprocessing on a line of code
function VergeC.preprocess(this, ln, i)
    local directive,params = string.match(ln, "^%s*#(%w+)%s+(.*)")
    
    if directive then
        if directive == 'include' then
            params = string.gsub(params, "[\"<](.*)[\">]", "%1")
            if not VergeC.modules[params] then VergeC.loadfile(params) end
        elseif directive == 'define' then
            local name,value = string.match(params, "([_%w][_%w%d]*)%s+(.*)");
            VergeC.defines[name] = value
        elseif directive == 'undef' then
            local name = string.match(params, "([_%w][_%w%d]*)");
            VergeC.defines[name] = nil
        elseif directive then
            this:error("PREPROCESSOR ERROR\n  Unknown preprocessor directive '" .. directive .. "'.", i)
        else
            this:error("PREPROCESSOR ERROR\n  Couldn't parse preprocessor directive.", i)
        end
        ln = ""
    else
        local k,v
        
        for k,v in pairs(VergeC.defines) do
            if v then ln = string.gsub(ln, k .. "([^_%w%d])", v .. "%1") end
        end
    end
    
    return ln
end
