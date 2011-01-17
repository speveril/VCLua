-- Our VergeC state
VergeC = {}

VergeC.bin = {}
VergeC.modules = {}
VergeC.defines = {}

require('vergec.bit') -- bitfield library by han zhao; see http://luaforge.net/projects/bit/
require('vergec.preprocessor')
require('vergec.tokenizer')
require('vergec.parser')
require('vergec.compiler')
require('vergec.runtime')

function VergeC.newModule()
    local m = {}
    
    m.index = 1
    m.furthestindex = 1
    m.code = ''
    m.ast = {}
    m.compiledcode = ''
    
    m.error = VergeC.error
    m.unload = VergeC.unload
    
    m.addLine = VergeC.addLine
    m.preprocess = VergeC.preprocess
    m.parse = VergeC.parse
    m.peek = VergeC.peek
    m.matchToken = VergeC.matchToken
    m.consume = VergeC.consume
    
    m.compile = VergeC.compile
    m.emit = VergeC.emit
    m.cleanNode = VergeC.cleanNode
    m.compileNode = VergeC.compileNode
    m.search = VergeC.search
    m.getVarType = VergeC.getVarType
    
    m.outputCode = VergeC.outputCode
    
    return m
end

function VergeC.unload(this)
    local i,v
    for i,v in ipairs(this.globals) do
        VergeC.scope[1][v] = nil
    end
end

function VergeC.call(func, args)
    if not args then args = {} end
    return VergeC.bin[func](unpack(args))
end

function VergeC.addLine(this, ln)
    this.code = this.code .. this:preprocess(ln, string.len(this.code)) .. "\n"
end

function VergeC.error(module, msg, index)
    if not index then index = module.furthestindex end
    local c = module.code
    local lineno = 1
    local lastnewln = 0
    local i
    
    for i = 1,index do
        if string.char(string.byte(c, i)) == "\n" then
            lastnewln = i
            lineno = lineno + 1
        end
    end
    
    local lnend = string.find(c, "\n", lastnewln + 1, true)
    if lnend then lnend = lnend - 1 end
    
    local ln = string.sub(c, lastnewln + 1, lnend)
    local col = index - lastnewln + 1
    
    ln = string.gsub(ln, "\t", "    ")
    
    msg = "** VERGEC " .. msg .."\nIn " .. module.filename .. " near line " .. lineno .. ", column " .. col .. ":\n" .. ln .. "\n" .. string.rep(" ", col-1) .. "^"
    v3.exit(msg)
end

-- Load a file and bring it into our VergeC state
function VergeC.loadfile(filename)
    print("VERGEC: Loading file '"..filename.."'")

    local module = VergeC.newModule()
    module.filename = filename
    VergeC.modules[filename] = module
    
    for line in io.lines(filename) do
        module:addLine(line)
    end
    
    --print(module.code)
    
    local succ
    module:consume(1) -- do this to consume any whitespace or comments at the beginning of the file

    print("VERGEC: Parsing " .. filename .. "...")
    module.ast,succ = module:parse()
    
    if succ and module.furthestindex > string.len(module.code) then
        print("VERGEC: Parsing complete.")
    else
        module:error("PARSING ERROR")
    end

    --VergeC.printAST(module.ast)
    
    print("VERGEC: Compiling " .. filename .. "...")
    module:compile()
    print("VERGEC: Compiling complete.")
    module:emit("\n-- done")
    
    --print("")
    --print(" LUA SOURCE (" .. filename .. "):")
    --module:outputCode(true)
    --print("")
    
    local cc = loadstring(module.compiledcode)
    if cc then
        cc()
    else
        print(module.compiledcode)
        module:error("Whoops! The generated Lua was no good. :(")
    end
    
    return module
    -- done
end

-- Print out an AST
function VergeC.printAST(ast, indent, norecurse)
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
    if ast.vartype then
        nodedesc = nodedesc .. "[" .. ast.vartype .. "]"
    end
    print(sp..nodedesc)

    if not norecurse then
        for i,v in ipairs(ast) do
            VergeC.printAST(v,indent+2)
        end
    end
end

function VergeC.outputCode(this, linenums)
    if not linenums then
        print(this.compiledcode)
    else
        local linenum = 1
        local linestart = 1
        local lineend = string.find(this.compiledcode, "\n", linestart, true)
        local ln = string.sub(this.compiledcode, linestart, lineend - 1)
        local codelen = string.len(this.compiledcode)
        
        while lineend < codelen do
            print(" " .. linenum .. "." .. "\t" .. ln)
            linenum = linenum + 1
            linestart = lineend + 1
            lineend = string.find(this.compiledcode, "\n", linestart, true)
            
            if not lineend then
                print(" " .. linenum .. "." .. "\t" .. string.sub(this.compiledcode, linestart))
                break
            end
            
            ln = string.sub(this.compiledcode, linestart, lineend - 1)
        end
    end
end
 