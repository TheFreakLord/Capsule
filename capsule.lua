local args = {...}
local fsc = fs.combine
local base = "/.capsule"
local tempName = fsc(base,"temp-" .. math.random(99999999))
local storage = fsc(base,"storage")

local ccfs = dofile("/usr/bin/capsule.deps/.glue/dep/ccfs/ccfs.lua")
local JSON = dofile("/usr/bin/capsule.deps/.glue/dep/json/main.lua")

if(not fs.isDir(base)) then fs.makeDir(base) end
if(not fs.isDir(storage)) then fs.makeDir(storage) end

local function pack(src,out)
  local function mapFolder(path)
    local content = {}
    for k,v in pairs(fs.list(fsc(src,path))) do
      if(fs.isDir(fsc(fsc(src,path),v))) then
        content[fsc(path,v)] = mapFolder(fsc(path,v))
      else
        local handle = fs.open(fsc(fsc(src,path),v),"r")
        local fileCont = handle.readAll()
        handle.close()
        content[fsc(path,v)] = fileCont
      end
    end
    return content
  end

  local compressed = mapFolder("/")
  local handle = fs.open(out,"w")
  handle.write(textutils.serialize(compressed))
  handle.close()
end

local function unpack(input,baseout)
  local handle = fs.open(input, "r")
  local content = handle.readAll()
  handle.close()
  local compressed = loadstring("return "..content)()

  local function reverse(tbl)
    for k,v in pairs(tbl) do
      if(type(v) == "table") then
        fs.makeDir(fsc(baseout,k))
        reverse(v)
      else
        local handle = fs.open(fsc(baseout,k),"w")
        handle.write(v)
        handle.close()
      end
    end
  end

  reverse(compressed)
end

if(args[1] == "install-capsule-internal") then
  fs.makeDir("/usr/bin/capsule.deps")
  shell.run("/usr/bin/glue init /usr/bin/capsule.deps")
  local handle = fs.open("/usr/bin/capsule.deps/GlueFile","w")
  handle.write([[
  depend "json" namespace "JSON" method "dofile"
  ]])
  handle.close()
  local oldDir = shell.dir()
  shell.setDir("/usr/bin/capsule.deps")
  shell.run("glue install")
  shell.setDir(oldDir)
elseif(args[1] == "uninstall-capsule-internal") then
  fs.delete("/usr/bin/capsule.deps")
else

  --shell.run("/usr/bin/capsule.deps/.glue/autoload.lua")

  if(args[1] == "init") then --initializes capsule
    local cur
    if(args[2] ~= nil) then
      if(not fs.exists(shell.resolve(args[2]))) then
        fs.makeDir(shell.resolve(args[2]))
      end
      cur = shell.resolve(args[2])
    else
      cur = shell.dir()
    end
    local conf = {}
    conf.name = ""
    conf.version = ""
    conf.author = ""
    conf.command = ""
    local handle = fs.open(fsc(cur,"capsule.json"),"w")
    handle.write(JSON.stringify(conf):gsub("{","{\n"):gsub(",",",\n"):gsub("}","\n}"))
    handle.close()
    shell.run("glue init",args[2])
  elseif(args[1] == "install") then --installs capsule into local storage
    if(args[2] == nil) then error() end
    local file = shell.resolve(args[2])
    if(not fs.exists(file) or fs.isDir(file)) then error() end
    local fileName = fs.getName(file)
    print("Installing capsule '" .. fileName .. "'")
    fs.copy(file,fsc(storage,fileName))
  elseif(args[1] == "compile") then --compiles capsule
    local cur = shell.dir()
    if(not fs.exists(fsc(cur, "capsule.json"))) then error() end
    if(not fs.exists(fsc(cur, "GlueFile"))) then error() end
    local handle = fs.open(fsc(cur, "capsule.json"),"r")
    local conf = JSON.parse(handle.readAll())
    handle.close()
    fs.delete(fsc(cur,".glue"))
    fs.delete(fsc(cur,conf.name .. ".capsule"))
    pack(cur,fsc(cur,conf.name .. ".capsule"))
    shell.run("glue install")
  elseif(args[1] == "run") then --runs a capsule
    if(args[2] == nil) then error() end
    local file = shell.resolve(args[2])
    if(not fs.exists(file)) then file = file..".capsule" end
    if(not fs.exists(file)) then file = fs.exists(fsc(storage,args[2])) and fsc(storage,args[2]) or (fs.exists(fsc(storage,args[2]..".capsule")) and fsc(storage,args[2]..".capsule") or error()) end
    local fileName = fs.getName(file)
    print("Starting capsule '"..fileName.."'")
    local rfs = ccfs.makeRamFS()
    local _fs = fs
    fs = rfs
    fs.import(file) --import capsule into fs
    fs.import("usr/bin/glue") --import glue into fs
    fs.lock()
    fs.copy(file, fileName)

    local handle = _fs.open("dump","w")
    handle.write(fs.dump())
    handle.close()

    print("yay")
    unpack(fileName,"/")
    print("nay")
    fs.delete(fileName)
    fs.delete(file)
    local oldDir = shell.dir()
    shell.setDir("/")
    print("Installing dependencies")
    print(fs.exists("src"))
    --shell.run("usr/bin/glue", "install")
    local handle = fs.open(fsc("/","capsule.json"),"r")
    local conf = JSON.parse(handle.readAll())
    handle.close()
    shell.run(conf.command)
    print("Capsule stopped.")
    print("cleaning up...")
    shell.setDir(oldDir)
    print("Done!")

    local handle = _fs.open("dump","w")
    handle.write(fs.dump())
    handle.close()

    fs = _fs
  end
end
