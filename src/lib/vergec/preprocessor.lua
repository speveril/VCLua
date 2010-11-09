-- Does preprocessing on the code
function VergeC.preprocess(this)
    print("VERGEC:  Preprocessing...")
    
    -- TODO: Parse #includes and #defines
    
    -- Strip comments
    --  This could make error reporting a little weird; should
    --  it be moved to the tokenizer and skipped like whitespace?
    this.code = string.gsub(this.code, "//.-\n", "\n")
    
    for comm in string.gmatch(this.code, "/%*(.-)%*/") do
        local repl = string.gsub(comm, "[^\n]", "")
        this.code = string.gsub(this.code, "/%*(.-)%*/", repl, 1)
    end
    
    this.code = string.gsub(this.code, "[ \t\n\r]*$", "")
    --print(this.code)
end
