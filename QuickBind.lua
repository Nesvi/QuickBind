function split(str, pat)
   local t = {} 
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function replaceDollar (str, replacement)

	cad = string.gsub(str, "%$", replacement)
	return cad

end

function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

function getInput()
	--return "class clase{ void metodo(int agfd, int b); void metodosasdfasd(const int agreg, const int cgfd&);  }"
	return readAll(arg[1])
end

function processClass(input)
	input = string.gsub(input, "#.-\n"," ")
	input = string.gsub(input, "%sstatic%s"," ")
	input = string.gsub(input, "%spublic:%s"," ")
	input = string.gsub(input, "%sprivate:%s"," ")
	
	a,b,classname,body = string.find(input,"class%s+(.-){(.*)}")
	local output = {}
	output.classname = classname
	output.methods = processMethods(input)
	return output
end

function processArgs(input)
	local output = {}
	local b = 0
	local c = 0
	local order = 1
	local vartypes = {"void","int","float","string","std::string","char","char*"}
	
	--Clean useless symbols for this work
	input = string.gsub(input, "const","")
	input = string.gsub(input, "[&]"," ")
	
	members = split(input,",")

	for i=1, #members do
		b=0
		a,b, argtype = string.find(members[i],"%s*(%S-)%s",b+1)
		if b == nil then 
			b = 0
			a,b, argtype = string.find(members[i],"%s*(%S-)$",b+1)
		end
		if b == nil then print "Error reading argument"; break; end
		
		output[order] = argtype
		order = order + 1
	end

	return output
	
end

complexTypes = {}
function checkType(typ)
	if typ ~= nil then
		local vartypes = {"void","int","float","string","std::string","char","char*"}
		local found = false
		for i=1, #vartypes do
			if vartypes[i] == typ then 
				found = true
				break
			end
		end
		
		if not found then
			found = false
			for i=1, #complexTypes do
				if complexTypes[i] == typ then 
					found = true
					break
				end
			end
			if not found then
				complexTypes[#complexTypes+1] = vartype
			end
		end
	end
end

function processMethods(input)
	local b=0
	local output = {}
	
	
	--for i=1, #vartypes do
		b= 0
		while true do
			a,b,vartype,method,args = string.find(input,(--[[vartypes[i]..]]"\n%s*([%a%*:]+)".."%s+([^;]-)%(([^;]-)%)[;]//BIND"),b+1)
			
			checkType(vartype)
			
			if b == nil then break; end 
			output[method] = processArgs(args)
			output[method].returnType = vartype--s[i]
		end
	--end
	return output
end

out = processClass(getInput())

--[[
*Now I must use this information to write the code of the bindings in c++!
-The name of the output class is = [name of the binded class]LuaQB
-Every time I bind a method without parameters and return I make an equivalent function in c++ with the following structure:

[name of the binded class]LuaQB_[method name](lua_State* L){
  [name of the binded class]LuaQB::getInstance(L)->[method name]();
  return 0;
}
]]--

function writeMethodCFunctions(classData)

	local bindingClassName = classData.classname .. "LuaQB"
	
	local functionBlock = ""
	
	for methodName, methodTable in pairs(classData.methods) do
		if methodTable.returnType == "void" then
			if #methodTable == 0 then
				functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\t" .. bindingClassName .. "::getInstance(L)->" .. methodName .. "();\n\treturn 0;\n}\n\n"
			else 
				functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\t" .. bindingClassName .. "::getInstance(L)->" .. methodName .. "("
				for i=1, #methodTable do					
					if methodTable[i] == "float" or methodTable[i] == "int" or methodTable[i] == "double" then 
						functionBlock = functionBlock .. "lua_tonumber(L," .. (i+1) .. ")"		
					elseif methodTable[i] == "std::string" or methodTable[i] == "string" then
						functionBlock = functionBlock .. "std::string(lua_tostring(L," .. (i+1) .. "))"
					elseif methodTable[i] == "char*" then
						functionBlock = functionBlock .. "lua_tostring(L," .. (i+1) .. ")"
					else						
						functionBlock = functionBlock .. "reinterpret_cast<"..methodTable[i]..">(lua_touserdata(L,"..(i+1).."))"
						checkType(methodTable[i])
					end
				
					if i ~= #methodTable then functionBlock = functionBlock .. ", " end
				end
				functionBlock = functionBlock .. ");\n\treturn 0;\n}\n\n"
			end
		elseif methodTable.returnType == "std::string" or methodTable.returnType == "string" then
			functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\tlua_pushstring(L," .. bindingClassName .. "::getInstance(L)->" .. methodName .. "("
			for i=1, #methodTable do					
				if methodTable[i] == "float" or methodTable[i] == "int" or methodTable[i] == "double" then 
					functionBlock = functionBlock .. "lua_tonumber(L," .. (i+1) .. ")"		
				elseif methodTable[i] == "std::string" or methodTable[i] == "string" then
					functionBlock = functionBlock .. "std::string(lua_tostring(L," .. (i+1) .. "))"
				elseif methodTable[i] == "char*" then
					functionBlock = functionBlock .. "lua_tostring(L," .. (i+1) .. ")"
				else
					functionBlock = functionBlock .. "reinterpret_cast<"..methodTable[i]..">(lua_touserdata(L,"..(i+1).."))"
					checkType(methodTable[i])
				end
				
				if i ~= #methodTable then functionBlock = functionBlock .. ", " end
			end
			functionBlock = functionBlock .. ").c_str());\n\treturn 1;\n}\n\n"
		
		elseif methodTable.returnType == "char*" then
			functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\tlua_pushstring(L," .. bindingClassName .. "::getInstance(L)->" .. methodName .. "("
			for i=1, #methodTable do					
				if methodTable[i] == "float" or methodTable[i] == "int" or methodTable[i] == "double" then 
					functionBlock = functionBlock .. "lua_tonumber(L," .. (i+1) .. ")"		
				elseif methodTable[i] == "std::string" or methodTable[i] == "string" then
					functionBlock = functionBlock .. "std::string(lua_tostring(L," .. (i+1) .. "))"
				elseif methodTable[i] == "char*" then
					functionBlock = functionBlock .. "lua_tostring(L," .. (i+1) .. ")"
				else
					functionBlock = functionBlock .. "reinterpret_cast<"..methodTable[i]..">(lua_touserdata(L,"..(i+1).."))"
					checkType(methodTable[i])
				end
				
				if i ~= #methodTable then functionBlock = functionBlock .. ", " end
			end
			functionBlock = functionBlock .. "));\n\treturn 1;\n}\n\n"
			
		elseif methodTable.returnType == "float" or methodTable.returnType == "int" or methodTable.returnType == "double" then
			functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\tlua_pushnumber(L," .. bindingClassName .. "::getInstance(L)->" .. methodName .. "("
			for i=1, #methodTable do					
				if methodTable[i] == "float" or methodTable[i] == "int" or methodTable[i] == "double" then 
					functionBlock = functionBlock .. "lua_tonumber(L," .. (i+1) .. ")"		
				elseif methodTable[i] == "std::string" or methodTable[i] == "string" then
					functionBlock = functionBlock .. "std::string(lua_tostring(L," .. (i+1) .. "))"
				elseif methodTable[i] == "char*" then
					functionBlock = functionBlock .. "lua_tostring(L," .. (i+1) .. ")"
				else
					functionBlock = functionBlock .. "reinterpret_cast<"..methodTable[i]..">(lua_touserdata(L,"..(i+1).."))"
					checkType(methodTable[i])
				end
				
				if i ~= #methodTable then functionBlock = functionBlock .. ", " end
			end
			functionBlock = functionBlock .. "));\n\treturn 1;\n}\n\n"
		else
			functionBlock = functionBlock .."int ".. bindingClassName .. "_" .. methodName .. "(lua_State* L){\n\tlua_pushlightuserdata(L," .. bindingClassName .. "::getInstance(L)->" .. methodName .. "("
			for i=1, #methodTable do					
				if methodTable[i] == "float" or methodTable[i] == "int" or methodTable[i] == "double" then 
					functionBlock = functionBlock .. "lua_tonumber(L," .. (i+1) .. ")"		
				elseif methodTable[i] == "std::string" or methodTable[i] == "string" then
					functionBlock = functionBlock .. "std::string(lua_tostring(L," .. (i+1) .. "))"
				elseif methodTable[i] == "char*" then
					functionBlock = functionBlock .. "lua_tostring(L," .. (i+1) .. ")"
				else
					functionBlock = functionBlock .. "reinterpret_cast<"..methodTable[i]..">(lua_touserdata(L,"..(i+1).."))"
					checkType(methodTable[i])
				end
				
				if i ~= #methodTable then functionBlock = functionBlock .. ", " end
			end
			functionBlock = functionBlock .. "));\n\treturn 1;\n}\n\n"
		end
	end
	
	functionBlock = functionBlock.."int ".. bindingClassName .. "_newUserData(lua_State* L){\n\tlua_pushlightuserdata(L,new "..classData.classname.."());\n\t return 1;\n}\n"
	
	return functionBlock
end
print(writeMethodCFunctions(out))

function writeLoadMethod(classData)

	local bindingClassName = classData.classname
	
	local code = "void "..bindingClassName.."LuaQB::load(lua_State* L){\n"
	for methodName, methodTable in pairs(classData.methods) do
		code = code .. "\tlua_register(L,\"QB"..bindingClassName.."_"..methodName.."\","..bindingClassName.."LuaQB_"..methodName..");\n"
	end
	code = code.."\tlua_register(L,\"QB"..bindingClassName.."_newUserData\","..bindingClassName.."LuaQB_newUserData);\n"
	code = code.."\tluaL_dofile(L,\""..classData.classname..".lua\");\n"
	code = code .. "}\n\n"
	return code
end
print(writeLoadMethod(out))

function writeGetInstanceMethod(classData)

	local bindingClassName = classData.classname .. "LuaQB"
	local code = classData.classname.."* "..bindingClassName.."::getInstance(lua_State* L){\n\treturn reinterpret_cast<"..classData.classname.."*>(lua_touserdata(L,1));\n}\n\n"
	return code;
end
print(writeGetInstanceMethod(out))

function writeInclude(classData)
	
	local bindingClassName = classData.classname .. "LuaQB"
	local code = ""--"extern \"C\" {\n#include <stdio.h>\n#include <stdlib.h>\n#include <lua.h>\n#include <lauxlib.h>\n#include <lualib.h>\n}\n\n"
	code = code .."#include \""..bindingClassName..".h\"\n"
	for i=1, #complexTypes do
		local myType = string.gsub(complexTypes[i],"%*","")
		code = code.."#include \""..myType..".h\"\n"
	end
	code = code .. "\n"
	return code
end
print(writeInclude(out))

function writeCppFile(classData)

	local bindingClassName = classData.classname .. "LuaQB"
	local output = writeInclude(classData)..writeMethodCFunctions(classData) .. writeLoadMethod(classData) .. writeGetInstanceMethod(classData)
	
	local f,err = io.open((bindingClassName..".cpp"),"w")
	if not f then return print(err) end
	f:write(output)
	f:close()

end

function writeHeaderFile(classData)
	local bindingClassName = classData.classname .. "LuaQB"
	local code = "#ifndef _"..bindingClassName.."\n#define _"..bindingClassName.."\n"
	code = code.."extern \"C\" {\n#include <stdio.h>\n#include <stdlib.h>\n#include <lua.h>\n#include <lauxlib.h>\n#include <lualib.h>\n}\n\n"
	code = code.."\n\n#include \""..classData.classname..".h\"\n\nclass "..bindingClassName.."{\n\tpublic:\n"
	
	code = code .."\t\tstatic "..classData.classname.."* getInstance(lua_State* L);\n"
	code = code .."\t\tstatic void load(lua_State* L);\n"
	
	code = code.."};\n#endif"
	
	local f,err = io.open((bindingClassName..".h"),"w")
	if not f then return print(err) end
	f:write(code)
	f:close()

end

function writeLuaFile(classData)

	local bindingClassName = classData.classname
	local code = ""
	code = code.."class.new \""..classData.classname.."\"\n\n"
	
	code = code .."function "..classData.classname..":initialize()\n\tself.C_userdata=QB"..bindingClassName.."_newUserData()\nend\n"
	for methodName, methodTable in pairs(classData.methods) do
		code = code.."function "..classData.classname..":"..methodName.."("		
		for i=1,#methodTable do
			code = code.."arg"..(i)
			if i ~= #methodTable then
				code = code..","
			end
		end
		code = code .. ")\n\treturn QB"..bindingClassName.."_"..methodName.."(self.C_userdata"
		if #methodTable >= 1 then code = code .. ","; end
		for i=1,#methodTable do
			code = code.."arg"..(i)
			if i ~= #methodTable then
				code = code..","
			end
		end
		code = code .. ")\nend\n"
	end
	
	local f,err = io.open((classData.classname..".lua"),"w")
	if not f then return print(err) end
	f:write(code)
	f:close()
	--code = code..
	--code = code..
	--code = code..
end

writeCppFile(out)
writeHeaderFile(out)
writeLuaFile(out)
--[[--Debug

function show(asdf,times)
	local spaces = ""
	for i=1,times do spaces = spaces.." " end

	for k,v in pairs(asdf) do
		if type(v)=="table" then
			print(spaces .. k.." -> " )
			show(v,times+2)
		else	
			print(spaces .. k.." -> "..v)
		end
	end
end

show(out,0)

]]--

