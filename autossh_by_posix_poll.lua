#! /usr/bin/env lua


local termio = require 'posix.termio'
local poll = require 'posix.poll'
local unistd = require 'posix.unistd'
local posix = require 'posix'

local function pipe()
   local r, w = unistd.pipe()
   assert(r ~= nil, w)
   return r, w
end

local master_fd, slave_fd = posix.openpty()

local pid, errmsg = unistd.fork()
assert(pid ~= nil, errmsg)

if pid == 0 then
   -- Child Process:
   unistd.setpid("s", unistd.getpid())
   unistd.close(master_fd)

   unistd.dup2(slave_fd, unistd.STDIN_FILENO)
   unistd.dup2(slave_fd, unistd.STDOUT_FILENO)
   unistd.dup2(slave_fd, unistd.STDERR_FILENO)
   unistd.exec("/bin/bash", {})

else
   -- Parent Process:
   print("child")
end

local function _writen(fd, data)
  unistd.write(fd, data)
end

local function _read(fd)
    return unistd.read(fd, 1024)
end

local function _copy(master_fd, master_read, stdin_read)

  local fds = {
     [master_fd] = {events={IN=true}},
     [unistd.STDIN_FILENO] = {events={IN=true}}
  }
  local stdin_callback = function(err, chunk)
      local data = stdin_read(unistd.STDIN_FILENO)
      if data then
        _writen(master_fd, data)
      end
    end

  local master_callback = function(err, chunk)
      local data = master_read(master_fd)
      if data then
        posix.write(unistd.STDOUT_FILENO, data)
      end
    end

  while true do
    poll.poll(fds, -1)
    for fd in pairs(fds) do
      if fds[fd].revents.IN then
         if fd == unistd.STDIN_FILENO then
           stdin_callback(nil, nil)
         elseif fd == master_fd then
           master_callback(nil, nil)
         end
      end
      if fds[fd].revents.HUP then
         unistd.close(fd)
         fds[fd] = nil
         if not next(fds) then
            return
         end
      end
    end
  end

end

local function process_msg(fd)
  local outs, errmsg = unistd.read(fd, 1024)
  if string.find(outs, "password:") then
    print("match")
    local password = "KDFEpvQTAg=="
    unistd.write(master_fd, password .. "\n")
  end
  return outs
end
_copy(master_fd, process_msg, _read)
-- end

--    while true do
--      read('STDOUT:', master_fd)
--      -- read('STDOUT:', stdout_r)
--    end
--    -- read('STDERR:', stderr_r)


--    local childpid, reason, status = require 'posix.sys.wait'.wait(pid)
--    assert(childpid ~= nil, reason)
--    print('child ' .. reason, status)
