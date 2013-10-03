function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
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

function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

function getInput()
	--return "class clase{ void metodo(int agfd, int b); void metodosasdfasd(const int agreg, const int cgfd&);  }"
	return readAll("Entity.h")
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
	print ("Analizando los argumentos: " .. input)
	local output = {}
	local b = 0
	local c = 0
	local order = 1
	local vartypes = {"void","int","float","string","char","char*"}
	
	--Limpieza de simbolos inútiles para lo que nos interesa
	input = string.gsub(input, "const","")
	input = string.gsub(input, "[&]"," ")
	
	members = split(input,",")

	for i=1, #members do
		b=0
		a,b, argtype = string.find(members[i],"%s*(%S-)%s",b+1)
		if b == nil then 
			a,b, argtype = string.find(members[i],"%s*(%S-)$",b+1)
		end
		if b == nil then print "Error reading argument"; break; end
		print(argtype)
		output[order] = argtype
		order = order + 1
	end
	--[[
	while true do

		a,b, argtype = string.find(input,"%s*(%S-)%s",b+1)
		if b == nil then break; end

		a,c, argname = string.find(input,"%s*(%S-)%s",b+1) -- si lo que analizamos es tal que ....float a); no detecta a porque está pegada al )
		if c == nil then 
			a,c, argname = string.find(input,"%s*(%S-)$",b+1)
		end

		b = c
		if b == nil then break; end

		output[order] = {}
		output[order].name = argname
		output[order].vartype = argtype 
		order = order + 1 
	end
	]]--
	return output
	
end

function processMethods(input)
	local b=0
	local output = {}
	
	local vartypes = {"void","int","float","string","char","char*"}
	for i=1, #vartypes do
		b= 0
		while true do
			a,b,method,args = string.find(input,(vartypes[i].."%s+([^;]-)%(([^;]-)%)[;]//BIND"),b+1)
			if b == nil then break; end
			output[method] = processArgs(args)
			output[method].returnType = vartypes[i]
		end
	end
	return output
end

out = processClass(getInput())

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


