lua.setup:
	luarocks install --tree lua/lua_modules --lua-version=5.1 luasocket --force

go.build:
	go build -o tmp/pairy .

setup: lua.setup go.build
