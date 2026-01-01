return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "zbirenbaum/copilot.lua",
    "AndreM222/copilot-lualine",
    'nvim-tree/nvim-web-devicons'
  },
  opts = {
    options = {
      theme = 'nord'
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch' },
      -- lualine_c show path to file
      lualine_c = { { 'filename', path = 1 } },
      lualine_x = { "copilot", 'encoding', 'filetype' },
      lualine_y = { 'progress' },
      lualine_z = { 'searchcount', 'location' }
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { 'filename' },
      lualine_x = { 'location' },
      lualine_y = {},
      lualine_z = {}
    },
    tabline = {},
    extensions = {}
  }
}
