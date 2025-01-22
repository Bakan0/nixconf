-- init.lua
vim.opt.runtimepath:prepend("/etc/neovim")
vim.opt.packpath:prepend("/etc/neovim/site")

-- Ensure proper data paths
vim.fn.stdpath = function(what)
  if what == 'data' then
    return '/etc/neovim/site'
  elseif what == 'config' then
    return '/etc/neovim'
  end
  return vim.fn.stdpath(what)
end

-- Load modules
require('options')
require('keymaps')
require('plugins')
require('colorscheme')
