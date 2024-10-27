#!/bin/bash

lib="$1"; shift
rest="$@"
version="${LV:-5.1}"
installer="${INSTALLER:-rocks}"


if [[ "$installer" == "rocks" ]]; then
    echo "luarocks install --tree lua/lua_modules --lua-version=$version $lib --force $rest"

    if [[ -z "$rest" ]]; then
        luarocks install --tree lua/lua_modules --lua-version="$version" "$lib" --force
    else
        luarocks install --tree lua/lua_modules "$rest" --lua-version=5.1 "$lib" --force
    fi

    exit 0
fi

if [[ "$installer" == "git" && ! -z "$rest" ]]; then
    echo "git clone $lib $rest"
    git clone "$lib" "$rest"
fi
