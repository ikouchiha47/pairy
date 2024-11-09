local M = {}
local uv = vim.loop

local stdout = uv.new_pipe(false)
local stderr = uv.new_pipe(false)

function M.runGoServer(args)
	M.server_handle = uv.spawn("go", {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		if signal == 0 then
			return
		end

		print(string.format("Go server exited with code %d and signal %d", code, signal))
		M.server_handle = nil
	end)

	if not M.server_handle then
		vim.notify("Failed to start Go server", vim.log.levels.ERROR)
	else
		vim.notify("Local server started successfully", vim.log.levels.INFO)
	end
end

function M.stopGoServer()
	if M.server_handle then
		M.server_handle:kill("sigkill")
		M.server_handle:close()
		M.server_handle = nil
		print("Go server stopped")
	else
		print("No Go server running")
	end
end

function M.isRunning()
	return M.server_handle ~= nil
end

uv.read_start(stdout, function(err, data)
	if data then
		print("stdout:", data)
		print("stdout:err", err)
	end
end)
uv.read_start(stderr, function(err, data)
	if data then
		print("stderr:", data)
		print("stderr:err", err)
	end
end)

return M
