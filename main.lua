--[[
		- RO SOCKET -
	A blazing fast implementation of WebSockets in roblox, similar to the "ws" library in Node.
	Supports client and server implementation.
	Backend uses the "ws" library aswell, providing proper socket support, and is coded in Node.
	
	• Creator: @binarychunk
	
		- CHANGELOG -
	
	v1.0.0:
		Initial release
	v1.0.1:
		Improved code readability
		Improved code speed by removing some useless portions
		Made it send all variable arguments from inside the Send function to the Reader
		Added more intelli sense stuff
		Added custom error messages when trying to:
		- send messages to a disconnected socket
		- disconnect a already-disconnected socket
]]--
function getmodule(name)
	return loadstring(game:HttpGet("https://github.com/gigimoose23/socketclient/blob/main/libs/" .. name .. ".lua?raw=true"))()
end
local RoSocket = {}
local Reader = getmodule("Reader")
local Errors =  {
	INVALID_ARGUMENT_TYPE = "Argument \"%s\" expected to be type %s, instead got %s!",

	EMPTY_WSS_LINK_TO_VALIDATE = "wss link expected, received none. Regex pattern can't be executed.",
	EMPTY_TEXT_TO_FORMAT = "text expected to be formatted, received none. Text formatting can't operate further more.",
	EMPTY_ID_TO_VALIDATE = "id expected, received none. ID validation can't operate further more.",

	INVALID_WSS_LINK = "invalid wss link received. Try connecting with a proper link!",

	HTTP_SERVICE_DISABLED = "RoSocket must have HTTP enabled for it to operate correctly. To resolve this problem, navigate to the top left corner, select FILE ➡ Game Settings ➡ Security ➡ <Allow HTTP Requests.",
	INVALID_REQUIREMENT_CONTEXT = "RoSocket must be required from a server-script directly, not a local-script. Please read our docs for further knowledge!"
}
local Signal = getmodule("Signal")
local Maid = getmodule("Maid")

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local SOCKET_SERVER_UPDATES = 0.10



local MaidSocket = Maid.new()
local Sockets = {}
RoSocket.Version = "1.0.1"
function RoSocket.SetSocketServer(link:string)
	Reader.SetSocketURL(link)
end
RoSocket.Connect = function(socket: string): (any?) -> (table)
	local validsocket = true

	if validsocket ~= false then
		local data = Reader:Connect(socket)
		if data.success ~= false then
			local dis = false
			local uuid = data.UUID
			local localmsgs = {}
			local localerrors = {}
			local tbl = {}
			tbl.readyState = dis
			coroutine.resume(coroutine.create(function() 
				while tbl do 
					tbl.readyState = dis and "CLOSED" or "OPEN"
					task.wait(0.05)
				end
			end))
			tbl.binaryType = "buffer"
			local OnDisconnect : RBXScriptSignal = Signal.new()
			tbl.OnDisconnect = OnDisconnect
			local OnMessageReceived : RBXScriptSignal = Signal.new()
			tbl.OnMessageReceived = OnMessageReceived
			local OnErrorReceived : RBXScriptSignal = Signal.new()
			tbl.OnErrorReceived = OnErrorReceived

			local elapsedTimer = Sockets[uuid] and Sockets[uuid].elapsedtimer or 0

			MaidSocket[uuid] = RunService.Heartbeat:Connect(function(deltaTime)

				if elapsedTimer >= SOCKET_SERVER_UPDATES then
					elapsedTimer = 0
				end
				elapsedTimer += deltaTime
				if elapsedTimer >= SOCKET_SERVER_UPDATES then
					if dis == false then
						-- messages
						local suc, Msgs = pcall(Reader.Get, Reader, uuid)
						if typeof(Msgs) == "table" then
							for _, msgobj in ipairs(Msgs) do
								local existsAlready = false
								for i,msg in ipairs(Sockets[uuid].msgs) do
									if msg.id == msgobj.id then
										existsAlready = true
										break
									end
								end

								if existsAlready == false then
									tbl.OnMessageReceived:Fire(msgobj.message)
									table.insert(Sockets[uuid].msgs, {
										id = msgobj.id,
										message = msgobj.message,
									})
									table.insert(localmsgs, {
										id = msgobj.id,
										message = msgobj.message,
									})
								end
							end
						end
						-- errors
						local suc, Msgs = pcall(Reader.GetErrors, Reader, uuid)
						if typeof(Msgs) == "table" then
							for _, msgobj in ipairs(Msgs) do
								local existsAlready = false
								for i,msg in ipairs(Sockets[uuid].errors) do
									if msg.id == msgobj.id then
										existsAlready = true
										break
									end
								end

								if existsAlready == false then
									tbl.OnErrorReceived:Fire(msgobj.message)
									table.insert(Sockets[uuid].errors, {
										id = msgobj.id,
										message = msgobj.message,
									})
									table.insert(localerrors, {
										id = msgobj.id,
										message = msgobj.message,
									})
								end
							end
						end
					else

					end
				end
			end)

			tbl.UUID = uuid
			tbl.Socket = data.Socket
			tbl.Disconnect = function(...)
				if dis == true then
					warn(Reader:FormatText("You cannot disconnect a disconnected socket!"))
					return false
				else
					local success = Reader:Disconnect(uuid)
					Sockets[uuid] = nil
					MaidSocket[uuid] = nil
					tbl.OnDisconnect:Fire()
					dis = true
					return true
				end
				
			end
			tbl.Send = function(...) 
				if dis == false then
					local success = Reader:Send(uuid, ...)
					return success
				else
					warn(Reader:FormatText("You cannot send messages to a disconnected socket!"))
					return false
				end
			end
			tbl.Messages = localmsgs or {}
			tbl.Errors = localerrors or {}

			setmetatable(tbl, {
				__call = function(self, index, ...) 
					return tbl[index](...)
				end,
				__metatable = "This is a protected metatable!"
			})
			Sockets[uuid] = {
				sockettbl = tbl,
				msgs = {},
				errors = {},
				elapsedtimer = 0
			}

			return tbl
		end
	else
		return {}
	end
end
setmetatable(RoSocket, {
	__call = function(self, ...)
		return RoSocket.Connect(...)
	end
})
table.freeze(RoSocket)
-----------------------------------------------
return RoSocket
