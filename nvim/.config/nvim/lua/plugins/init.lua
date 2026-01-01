return {
  { "kylechui/nvim-surround",  version = "*", event = "VeryLazy", config = true },
  { "akinsho/bufferline.nvim", config = true },
  "nvim-telescope/telescope.nvim",
  "mbbill/undotree",
  { "kyazdani42/nvim-tree.lua", config = true },
  "folke/trouble.nvim",
  "nvim-treesitter/nvim-treesitter",
  "powerman/vim-plugin-ruscmd",
  "sindrets/winshift.nvim",
  "tpope/vim-repeat",
  "goolord/alpha-nvim",
  { 'windwp/nvim-autopairs',    event = "InsertEnter", config = true }



  -- {
  --   "windwp/nvim-ts-autotag",
  --   dependencies = { "nvim-treesitter/nvim-treesitter" },
  --   setup = {
  --     opts = {
  --       -- Defaults
  --       enable_close = true,          -- Auto close tags
  --       enable_rename = true,         -- Auto rename pairs of tags
  --       enable_close_on_slash = false -- Auto close on trailing </
  --     },
  --     -- Also override individual filetype configs, these take priority.
  --     -- Empty by default, useful if one of the "opts" global settings
  --     -- doesn't work well in a specific filetype
  --     per_filetype = {
  --       ["html"] = {
  --         enable_close = false
  --       }
  --     }
  --   }
  -- }

}
