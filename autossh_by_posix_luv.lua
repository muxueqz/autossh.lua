#! /usr/bin/env lua


local termio = require 'posix.termio'
local fcntl  = require 'posix.fcntl'
local unistd = require 'posix.unistd'
local posix = require 'posix'
local uv = require('luv')

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
   -- M.dup2(stdout_w, M.STDOUT_FILENO)
   -- M.dup2(stderr_w, M.STDERR_FILENO)
   unistd.exec("/bin/bash", {})
   -- M.exec("/usr/bin/ssh", {"127.1"})

   -- Exec() a subprocess here instead if you like --

   -- io.stdout:write 'output string'
   -- io.stderr:write 'oh noes!'
   -- os.exit(42)

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
  local poll = uv.new_poll(unistd.STDIN_FILENO)
  local callback = function(err, chunk)
      local data = stdin_read(unistd.STDIN_FILENO)
      if data then
        _writen(master_fd, data)
      end
    end
  uv.poll_start(poll, "r", callback)
  local poll = uv.new_poll(master_fd)
  local callback = function(err, chunk)
      local data = master_read(master_fd)
      if data then
        posix.write(unistd.STDOUT_FILENO, data)
      end
    end
  uv.poll_start(poll, "r", callback)
  uv.run()
end

local function process_msg(fd)
  local outs, errmsg = unistd.read(fd, 1024)
  if string.find(outs, "password:") then
    print("match")
    posix.write(master_fd, "password\n")
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
