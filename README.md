# pairy

## Requirements

- lua >= 5.1
- go
- neovim

## Install

`make setup`

```lua
local dir = '/home/darksied/dev/pairy'

return {
  name = 'pairy',
  dir = dir,
  config = function()
    local Pairy = require 'nvimer'
    Pairy.setup {
      pwd = dir,
      laddr = '0.0.0.0',
      lport = 8080,
    }
  end,
}
```

## Usage

- `:PairyServe`
- `:PairyPair <address>`
- `:PairyUnpair`
- `:PairyKill`
