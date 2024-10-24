# pairy

## Requirements

- lua >= 5.1
- go
- neovim

## Install

`make setup`

```lua
return {
  name = 'pairy',
  dir = '/path/to/pairy',
  config = function()
    local Pairy = require 'nvimer'
    Pairy.setup '/path/to/pairy' -- Pass the project root as pwd
  end,
}
```

## Usage

- `:Pair <address>`
