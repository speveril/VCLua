-- Does preprocessing on the code
function VergeC.preprocess(this)
    print("VERGEC:  Preprocessing...")
    
    -- TODO: Parse #includes and #defines
    
    -- Strip comments
    --  comment skipping has been moved to VergeC.consume in tokenizer.lua
    --this.code = string.gsub(this.code, "//.-\n", "\n")
    --
    --for comm in string.gmatch(this.code, "/%*(.-)%*/") do
    --    local repl = string.gsub(comm, "[^\n]", "")
    --    this.code = string.gsub(this.code, "/%*(.-)%*/", repl, 1)
    --end
    
    --print(this.code)
end
