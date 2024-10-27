lua.setup:
	luarocks install --tree lua/lua_modules --lua-version=5.1 luasocket --force
	INSTALLER=git ./rocksinstall.sh https://github.com/mpeterv/sha1.git lua/lua_modules/lib/lua/5.1/sha1

go.build:
	go build -o tmp/pairy .

setup: lua.setup go.build
