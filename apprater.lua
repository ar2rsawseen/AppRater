--[[
	Save Table to File/Stringtable
	Load Table from File/Stringtable
	v 0.94
 
	Lua 5.1 compatible
 
	Userdata and indices of these are not saved
	Functions are saved via string.dump, so make sure it has no upvalues
	References are saved
	----------------------------------------------------
	table.save( table [, filename] )
 
	Saves a table so it can be called via the table.load function again
	table must a object of type 'table'
	filename is optional, and may be a string representing a filename or true/1
 
	table.save( table )
		on success: returns a string representing the table (stringtable)
		(uses a string as buffer, ideal for smaller tables)
	table.save( table, true or 1 )
		on success: returns a string representing the table (stringtable)
		(uses io.tmpfile() as buffer, ideal for bigger tables)
	table.save( table, "filename" )
		on success: returns 1
		(saves the table to file "filename")
	on failure: returns as second argument an error msg
	----------------------------------------------------
	table.load( filename or stringtable )
 
	Loads a table that has been saved via the table.save function
 
	on success: returns a previously saved table
	on failure: returns as second argument an error msg
	----------------------------------------------------
 
	chillcode, http://lua-users.org/wiki/SaveTableToFile
	Licensed under the same terms as Lua itself.
]]--
do
	-- declare local variables
	--// exportstring( string )
	--// returns a "Lua" portable version of the string
	local function exportstring( s )
		s = string.format( "%q",s )
		-- to replace
		s = string.gsub( s,"\\\n","\\n" )
		s = string.gsub( s,"\r","\\r" )
		s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
		return s
	end
--// The Save Function
function table.save(  tbl,filename )
	local charS,charE = "   ","\n"
	local file,err
	-- create a pseudo file that writes to a string and return the string
	if not filename then
		file =  { write = function( self,newstr ) self.str = self.str..newstr end, str = "" }
		charS,charE = "",""
	-- write table to tmpfile
	elseif filename == true or filename == 1 then
		charS,charE,file = "","",io.tmpfile()
	-- write table to file
	-- use io.open here rather than io.output, since in windows when clicking on a file opened with io.output will create an error
	else
		file,err = io.open( filename, "w" )
		if err then return _,err end
	end
	-- initiate variables for save procedure
	local tables,lookup = { tbl },{ [tbl] = 1 }
	file:write( "return {"..charE )
	for idx,t in ipairs( tables ) do
		if filename and filename ~= true and filename ~= 1 then
			file:write( "-- Table: {"..idx.."}"..charE )
		end
		file:write( "{"..charE )
		local thandled = {}
		for i,v in ipairs( t ) do
			thandled[i] = true
			-- escape functions and userdata
			if type( v ) ~= "userdata" then
				-- only handle value
				if type( v ) == "table" then
					if not lookup[v] then
						table.insert( tables, v )
						lookup[v] = #tables
					end
					file:write( charS.."{"..lookup[v].."},"..charE )
				elseif type( v ) == "function" then
					file:write( charS.."loadstring("..exportstring(string.dump( v )).."),"..charE )
				else
					local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
					file:write(  charS..value..","..charE )
				end
			end
		end
		for i,v in pairs( t ) do
			-- escape functions and userdata
			if (not thandled[i]) and type( v ) ~= "userdata" then
				-- handle index
				if type( i ) == "table" then
					if not lookup[i] then
						table.insert( tables,i )
						lookup[i] = #tables
					end
					file:write( charS.."[{"..lookup[i].."}]=" )
				else
					local index = ( type( i ) == "string" and "["..exportstring( i ).."]" ) or string.format( "[%d]",i )
					file:write( charS..index.."=" )
				end
				-- handle value
				if type( v ) == "table" then
					if not lookup[v] then
						table.insert( tables,v )
						lookup[v] = #tables
					end
					file:write( "{"..lookup[v].."},"..charE )
				elseif type( v ) == "function" then
					file:write( "loadstring("..exportstring(string.dump( v )).."),"..charE )
				else
					local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
					file:write( value..","..charE )
				end
			end
		end
		file:write( "},"..charE )
	end
	file:write( "}" )
	-- Return Values
	-- return stringtable from string
	if not filename then
		-- set marker for stringtable
		return file.str.."--|"
	-- return stringttable from file
	elseif filename == true or filename == 1 then
		file:seek ( "set" )
		-- no need to close file, it gets closed and removed automatically
		-- set marker for stringtable
		return file:read( "*a" ).."--|"
	-- close file and return 1
	else
		file:close()
		return 1
	end
end
 
--// The Load Function
function table.load( sfile )
	local tables, err, _
	-- catch marker for stringtable
	if string.sub( sfile,-3,-1 ) == "--|" then
		tables,err = loadstring( sfile )
	else
		tables,err = loadfile( sfile )
	end
	if err then return _,err
	end
	tables = tables()
	for idx = 1,#tables do
		local tolinkv,tolinki = {},{}
		for i,v in pairs( tables[idx] ) do
			if type( v ) == "table" and tables[v[1]] then
				table.insert( tolinkv,{ i,tables[v[1]] } )
			end
			if type( i ) == "table" and tables[i[1]] then
				table.insert( tolinki,{ i,tables[i[1]] } )
			end
		end
		-- link values, first due to possible changes of indices
		for _,v in ipairs( tolinkv ) do
			tables[idx][v[1]] = v[2]
		end
		-- link indices
		for _,v in ipairs( tolinki ) do
			tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
		end
	end
	return tables[1]
end
-- close do
end

AppRater = Core.class()

function AppRater:init(config)
	self.conf = {
		androidRate = "", --link to rate Android app
		iosRate = "",     --link to rate IOS app
		timesUsed = 15,   --times to use before asking to rate
		daysUsed = 30,    --days to use before asking to rate
		version = 0,      --current version of the app
		remindTimes = 5,  --times of use to wait before reminding
		remindDays = 5,    --days of use to wait before reminding
		rateTitle = "Rate My App",
		rateText = "Please rate my app",
		rateButton = "Rate it now!",
		remindButton = "Remind me later",
		cancelButton = "No, thanks"
	}
	
	if config then
		--copying configuration
		for key,value in pairs(config) do
			self.conf[key]= value
		end
	end
	
	self.data = table.load("|D|apprater")
	if self.data == nil or self.data.version ~= self.conf.version then
		self:reset()
	elseif self.data.toRate then
		self:step()
	end
end

function AppRater:reset()
	self.data = {
		startDate = os.timer(),
		timesUsed = 1,
		version = self.conf.version,
		daysToWait = self.conf.daysUsed,
		timesToWait = self.conf.timesUsed,
		toRate = true
	}
	table.save(self.data, "|D|apprater")
end

function AppRater:step()
	self.data.timesUsed = self.data.timesUsed + 1
	if self.data.timesUsed >= self.data.timesToWait then
		self:rate()
	else
		local now = os.timer()
		local days = math.floor((((now - self.data.startDate) / 60) / 60) / 24)
		if days >= self.data.daysToWait then
			self:rate()
		end
	end
	table.save(self.data, "|D|apprater")
end

function AppRater:rate()
	local alertDialog = AlertDialog.new(self.conf.rateTitle, self.conf.rateText, self.conf.cancelButton, self.conf.rateButton, self.conf.remindButton)

	local function onComplete(event)
		if event.buttonIndex == 1 then
			self.data.toRate = false
			table.save(self.data, "|D|apprater")
			local osName = application:getDeviceInfo()
			if osName == "Android" and self.conf.androidRate ~= "" then
				application:openUrl(self.conf.androidRate)
			elseif osName == "iOS" and self.conf.iosRate ~= "" then
				application:openUrl(self.conf.iosRate)
			end
		elseif event.buttonIndex == 2 then
			self.data.daysToWait = self.data.daysToWait + self.conf.remindDays
			self.data.timesToWait = self.data.timesToWait + self.conf.remindTimes
			table.save(self.data, "|D|apprater")
		else
			self.data.toRate = false
			table.save(self.data, "|D|apprater")
		end
	end

	alertDialog:addEventListener(Event.COMPLETE, onComplete)
	alertDialog:show()
end