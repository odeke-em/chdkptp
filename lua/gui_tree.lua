--[[
 Copyright (C) 2010-2011 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
]]
--[[
module for gui tree view
]]
local m={}
local itree=iup.tree{}
itree.name="Camera"
itree.state="collapsed"
itree.addexpanded="NO"
-- itree.addroot="YES"

function itree:get_data(id)
	return iup.TreeGetUserId(self,id)
end

-- TODO we could keep a map somewhere
function itree:get_id_from_path(fullpath)
	local id = 0
	while true do
		local data = self:get_data(id)
		if data then
			if not data.dummy then
				if data:fullpath() == fullpath then
					return id
				end
			end
		else
			return
		end
		id = id + 1
	end
end

-- TODO
local filetreedata_getfullpath = function(self)
	-- root is special special, we don't want to add slashes
	if self.name == 'A/' then
		return 'A/'
	end
	if self.path == 'A/' then
		return self.path .. self.name
	end
	return self.path .. '/' .. self.name
end

function itree:set_data(id,data)
	data.fullpath = filetreedata_getfullpath
	iup.TreeSetUserId(self,id,data)
end

local function do_download_dialog(data)
	local remotepath = data:fullpath()
	local filedlg = iup.filedlg{
		dialogtype = "SAVE",
		title = "Download "..remotepath, 
		filter = "*.*", 
		filterinfo = "all files",
		file = fsutil.basename(remotepath)
	} 

-- Shows file dialog in the center of the screen
	statusprint('download dialog ' .. remotepath)
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

-- Gets file dialog status
	local status = filedlg.status

-- new or overwrite (windows native dialog already prompts for overwrite)
	if status == "1" or status == "0" then 
		statusprint("d "..remotepath.."->"..filedlg.value)
		-- can't use mdownload here because local name might be different than remote basename
		add_status(con:download(remotepath,filedlg.value))
		add_status(lfs.touch(filedlg.value,chdku.ts_cam2pc(data.stat.mtime)))
-- canceled
--	elseif status == "-1" then 
	end
end

local function do_dir_download_dialog(data)
	local remotepath = data:fullpath()
	local filedlg = iup.filedlg{
		dialogtype = "DIR",
		title = "Download contents of "..remotepath, 
	} 

-- Shows dialog in the center of the screen
	statusprint('dir download dialog ' .. remotepath)
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

-- Gets dialog status
	local status = filedlg.status

	if status == "0" then 
		statusprint("d "..remotepath.."->"..filedlg.value)
		add_status(con:mdownload({remotepath},filedlg.value))
	end
end

local function do_dir_upload_dialog(data)
	local remotepath = data:fullpath()
	local filedlg = iup.filedlg{
		dialogtype = "DIR",
		title = "Upload contents to "..remotepath, 
	} 
-- Shows dialog in the center of the screen
	statusprint('dir upload dialog ' .. remotepath)
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

-- Gets dialog status
	local status = filedlg.status

	if status == "0" then 
		statusprint("d "..remotepath.."->"..filedlg.value)
		add_status(con:mupload({filedlg.value},remotepath))
		itree:refresh_tree_by_path(remotepath)
	end
end


local function do_upload_dialog(remotepath)
	local filedlg = iup.filedlg{
		dialogtype = "OPEN",
		title = "Upload to: "..remotepath, 
		filter = "*.*", 
		filterinfo = "all files",
		multiplefiles = "yes",
	} 
	statusprint('upload dialog ' .. remotepath)
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

-- Gets file dialog status
	local status = filedlg.status
	local value = filedlg.value
-- new or overwrite (windows native dialog already prompts for overwrite
	if status ~= "0" then
		statusprint('upload canceled status ' .. status)
		return
	end
	statusprint('upload value ' .. tostring(value))
	local paths = {}
	local e=1
	local dir
	while true do
		local s,sub
		s,e,sub=string.find(value,'([^|]+)|',e)
		if s then
			if not dir then
				dir = sub
			else
				table.insert(paths,fsutil.joinpath(dir,sub))
			end
		else
			break
		end
	end
	-- single select
	if #paths == 0 then
		table.insert(paths,value)
	end
	-- note native windows dialog does not allow multi-select to include directories.
	-- If it did, each to-level directory contents would get dumped into the target dir
	-- should add an option to mupload to include create top level dirs
	-- TODO test gtk/linux
	add_status(con:mupload(paths,remotepath))
	itree:refresh_tree_by_path(remotepath)
end

local function do_mkdir_dialog(data)
	local remotepath = data:fullpath()
	local dirname = iup.Scanf("Create directory\n"..remotepath.."%64.11%s\n",'');
	if dirname then
		printf('mkdir: %s',dirname)
		add_status(con:mkdir_m(fsutil.joinpath_cam(remotepath,dirname)))
		itree:refresh_tree_by_path(remotepath)
	else
		printf('mkdir canceled')
	end
end

local function do_delete_dialog(data)
	local msg
	local fullpath = data:fullpath()
	if data.stat.is_dir then
		msg = 'delete directory ' .. fullpath .. ' and all contents ?'
	else
		msg = 'delete ' .. fullpath .. ' ?'
	end
	if iup.Alarm('Confirm delete',msg,'OK','Cancel') == 1 then
		add_status(con:mdelete({fullpath}))
		itree:refresh_tree_by_path(fsutil.dirname_cam(fullpath))
	end
end

function itree:refresh_tree_by_id(id)
	if not id then
		printf('refresh_tree_by_id: nil id')
		return
	end
	local oldstate=self['state'..id]
	local data=self:get_data(id)
	statusprint('old state', oldstate)
	self:populate_branch(id,data:fullpath())
	if oldstate and oldstate ~= self['state'..id] then
		self['state'..id]=oldstate
	end
end

function itree:refresh_tree_by_path(path)
	printf('refresh_tree_by_path: %s',tostring(path))
	local id = self:get_id_from_path(path)
	if id then
		printf('refresh_tree_by_path: found %s',tostring(id))
		self:refresh_tree_by_id(id)
	else
		printf('refresh_tree_by_path: failed to find %s',tostring(path))
	end
end
--[[
function itree:dropfiles_cb(filename,num,x,y)
	-- note id -1 > not on any specific item
	local id = iup.ConvertXYToPos(self,x,y)
	printf('dropfiles_cb: %s %d %d %d %d\n',filename,num,x,y,id)
end
]]

function itree:rightclick_cb(id)
	local data=self:get_data(id)
	if not data then
		return
	end
	if data.fullpath then
		statusprint('tree right click: fullpath ' .. data:fullpath())
	end
	if data.stat.is_dir then
		iup.menu{
			iup.item{
				title='Refresh',
				action=function()
					self:refresh_tree_by_id(id)
				end,
			},
			-- the default file selector doesn't let you multi-select with directories
			iup.item{
				title='Upload files...',
				action=function()
					do_upload_dialog(data:fullpath())
				end,
			},
			iup.item{
				title='Upload directory contents...',
				action=function()
					do_dir_upload_dialog(data)
				end,
			},
			iup.item{
				title='Download contents...',
				action=function()
					do_dir_download_dialog(data)
				end,
			},
			iup.item{
				title='Create directory...',
				action=function()
					do_mkdir_dialog(data)
				end,
			},
			iup.item{
				title='Delete...',
				action=function()
					do_delete_dialog(data)
				end,
			},
		}:popup(iup.MOUSEPOS,iup.MOUSEPOS)
	else
		iup.menu{
			iup.item{
				title='Download...',
				action=function()
					do_download_dialog(data)
				end,
			},
			iup.item{
				title='Delete...',
				action=function()
					do_delete_dialog(data)
				end,
			},
		}:popup(iup.MOUSEPOS,iup.MOUSEPOS)
	end
end

function itree:populate_branch(id,path)
	self['delnode'..id] = "CHILDREN"
	statusprint('populate branch '..id..' '..path)
	if id == 0 then
		itree.state="collapsed"
	end		
	local list,msg = con:listdir(path,{stat='*'})
	if type(list) == 'table' then
		chdku.sortdir_stat(list)
		for i=#list, 1, -1 do
			st = list[i]
			if st.is_dir then
				self['addbranch'..id]=st.name
				self:set_data(self.lastaddnode,{name=st.name,stat=st,path=path})
				-- dummy, otherwise tree nodes not expandable
				-- TODO would be better to only add if dir is not empty
				self['addleaf'..self.lastaddnode] = 'dummy'
				self:set_data(self.lastaddnode,{dummy=true})
			else
				self['addleaf'..id]=st.name
				self:set_data(self.lastaddnode,{name=st.name,stat=st,path=path})
			end
		end
	end
end

function itree:branchopen_cb(id)
	statusprint('branchopen_cb ' .. id)
	if not con:is_connected() then
		statusprint('branchopen_cb not connected')
		return iup.IGNORE
	end
	local path
	if id == 0 then
		path = 'A/'
		-- chdku.exec('return os.stat("A/")',{libs={'serialize','serialize_msgs'}})
		-- TODO
		-- self:set_data(0,{name='A/',stat={is_dir=true},path=''})
		itree:set_data(0,{name='A/',stat={is_dir=true},path=''})
	end
	local data = self:get_data(id)
	self:populate_branch(id,data:fullpath())
end

-- empty the tree, and add dummy we always re-populate on expand anyway
-- this crashes in gtk
--[[
function itree:branchclose_cb(id)
	self['delnode'..id] = "CHILDREN"
	self['addleaf'..id] = 'dummy'
end
]]

function m.init()
	return
end

function m.get_container()
	return itree
end

function m.get_container_title()
	return "Files"
end

function m.on_dlg_run()
	itree.addbranch0="dummy"
	itree:set_data(0,{name='A/',stat={is_dir=true},path=''})
end
return m
