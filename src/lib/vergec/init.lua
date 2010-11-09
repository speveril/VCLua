-- Our VergeC state
VergeC = {}

require('vergec.preprocessor')
require('vergec.tokenizer')
require('vergec.parser')

function VergeC.newModule()
    local m = {}
    
    m.index = 1
    m.furthestindex = 1
    m.code = ''
    m.ast = {}
    m.compiledcode = ''
    
    m.addLine = VergeC.addLine
    m.preprocess = VergeC.preprocess
    m.parse = VergeC.parse
    m.compile = VergeC.compile
    m.peek = VergeC.peek
    m.consume = VergeC.consume
    
    return m
end

function VergeC.addLine(this, ln)
    this.code = this.code .. ln .. "\n"
end

-- Load a file and bring it into our VergeC state
function VergeC.loadfile(filename)
    print("VERGEC: Loading file '"..filename.."'")

    module = VergeC.newModule()    
    for line in io.lines(filename) do
        module:addLine(line)
    end
    
    module:preprocess()
    --print(module.code)
    
    local succ
    module.ast,succ = module:parse()
    
    if succ and module.furthestindex >  string.len(module.code) then
        print("VERGEC: Parsing successful!")
    else
        local c = module.code
        local lineno = 1
        local lastnewln = 0
        local i
        
        for i = 1,module.furthestindex do
            if string.char(string.byte(c, i)) == "\n" then
                lastnewln = i
                lineno = lineno + 1
            end
        end
        
        local ln = string.sub(c, lastnewln + 1, string.find(c, "\n", lastnewln + 1, true) - 1)
        local col = module.furthestindex - lastnewln + 1
        
        ln = string.gsub(ln, "\t", "    ")
                
        print("** VERGEC PARSE FAILURE near line " .. lineno .. ", column " .. col .. ":")
        print(ln)
        print(string.rep(" ", col-1) .. "^")
        
        return
    end

    VergeC.printAST(module.ast)
    
    module:compile()
    
    -- done
end


-- Print out an AST
function VergeC.printAST(ast, indent)
    if not ast then return end
    if type(ast) ~= 'table' then return end
    
    if not indent then indent = 0 end
    
    local sp = string.rep(' ', indent)
    local i,v
    
    local nodedesc = "Node: "
    if ast.name then nodedesc = nodedesc .. ast.name .. " " end
    if ast.type == 'TOKEN' then
        nodedesc = nodedesc .. "'" .. ast.value .. "' (" .. ast.token_type .. ")"
    else
        nodedesc = nodedesc .. "("..ast.type
        if ast.value then nodedesc = nodedesc .. ", " .. ast.value end
        nodedesc = nodedesc .. ")"
    end
    print(sp..nodedesc)

    for i,v in ipairs(ast) do
        VergeC.printAST(v,indent+2)
    end
end

function VergeC.compile(this)
    
end
