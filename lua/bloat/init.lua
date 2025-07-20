local M = {}

local BLOAT_DIR = vim.fn.stdpath("state") .. "/bloat.nvim/"

---@class BloatHightlightOpts
---@field fg string
---@field bg string

---@class BloatOpts
---@field width number
---@field height number
---@field highlight BloatHightlightOpts
---@field border "double" | "none" | "rounded" | "shadow" | "single" | "solid"
---@field name_prefix string
local OPTS = {}

---@type boolean
local windowIsOpen = false
---@type number
local windowId = -1
---@type number
local lastBufNr = -1

---@type table<number, string[]>
local bufNrNameMap = {}
---@type number
local count = 0

---@return string
function GetCwdSha()
  return vim.fn.sha256(vim.fn.getcwd()):sub(1, 16)
end

---@param fileName string
---@return string
function GetFileName(fileName)
  return vim.fn.stdpath("state") .. "/bloat.nvim/" .. GetCwdSha() .. "_" .. fileName:gsub(" ", "--")
end

function Init()
  if not vim.uv.fs_stat(BLOAT_DIR) then
    vim.uv.fs_mkdir(BLOAT_DIR, tonumber("755", 8))
  end

  ---@type uv.luv_dir_t|nil
  local dir = vim.uv.fs_opendir(BLOAT_DIR)
  if dir ~= nil then
    ---@type uv.fs_readdir.entry[]|nil
    local entries = vim.uv.fs_readdir(dir)
    while entries ~= nil do
      local sha = GetCwdSha()
      for _, v in ipairs(entries) do
        if v.type == "file" and v.name:sub(1, #sha) == sha then
          local fileName = BLOAT_DIR .. v.name

          local bufNr = CreateBuffer(fileName)
          local bufName = v.name:sub(v.name:find("_", 1, true) + 1):gsub("%-%-", " ")

          bufNrNameMap[bufNr] = { bufName, fileName }
          count = count + 1
        end
      end

      entries = vim.uv.fs_readdir(dir)
    end

    vim.uv.fs_closedir(dir)
  else
    print("[ERROR] bloat.nvim: Failed to open BLOAT_DIR='" .. BLOAT_DIR .. "'")
  end
end

---@param bufNr number
---@param bufName string
function CreateWindow(bufNr, bufName)
  local width = math.floor(vim.o.columns * (OPTS.width or 0.75))
  local height = math.floor(vim.o.lines * (OPTS.height or 0.75))
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  local highlight = "FloatTitle"
  if OPTS.highlight.bg and OPTS.highlight.fg then
    highlight = "BloatTitle"
    vim.cmd(
      "highlight " .. highlight .. " guibg=" .. OPTS.highlight.bg .. " guifg=" .. OPTS.highlight.fg .. " gui=bold"
    )
  end

  ---@type vim.api.keyset.win_config
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = OPTS.border or "single",
    title = { { " " .. bufName .. " ", highlight } },
    title_pos = "left",
  }

  windowId = vim.api.nvim_open_win(bufNr, true, opts)

  windowIsOpen = true
  lastBufNr = bufNr
end

---@param bufFileName string
---@return number
function CreateBuffer(bufFileName)
  local bufNr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufNr, bufFileName)

  vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
    buffer = bufNr,
    callback = function()
      if windowIsOpen then
        windowIsOpen = false
      end
    end,
  })

  return bufNr
end

function Close()
  if windowIsOpen then
    vim.api.nvim_win_close(windowId, true)
    windowIsOpen = false
  end
end

---@param opts table<"args", string | "">
function Create(opts)
  if windowIsOpen then
    Close()
  end

  local bufName = (opts.args ~= "" and opts.args) or ((OPTS.name_prefix or "Scratch") .. " " .. count)
  local bufFileName = GetFileName(bufName)

  local bufNr = CreateBuffer(bufFileName)

  CreateWindow(bufNr, bufName)
  bufNrNameMap[bufNr] = { bufName, bufFileName }
  count = count + 1
end

---@param opts table<"args", string>
function Open(opts)
  if opts.args == nil then
    print("[ERROR] bloat.nvim: Unable to find any buffer to open!")
    return
  end

  if windowIsOpen then
    Close()
  end

  local bufNr = -1
  for k, v in pairs(bufNrNameMap) do
    if v[1] == opts.args then
      bufNr = k
    end
  end

  if bufNr == -1 then
    print("[ERROR] bloat.nvim: Unable to find any buffer by name '" .. opts.args .. "' to open!")
    return
  end

  if not vim.api.nvim_buf_is_valid(bufNr) then
    local fileName = GetFileName(opts.args)
    local newBufNr = vim.fn.bufnr(fileName)

    bufNrNameMap[newBufNr] = { opts.args, fileName }
    bufNrNameMap[bufNr] = nil

    bufNr = newBufNr
  end

  CreateWindow(bufNr, opts.args)
end

function Toggle()
  if windowIsOpen then
    Close()
  else
    Open({ args = bufNrNameMap[lastBufNr][1] })
  end
end

---@param opts table<"args", string>
function Rename(opts)
  if lastBufNr == -1 then
    print("[ERROR] bloat.nvim: Unable to rename as there are no buffers created!")
    return
  end

  if not vim.api.nvim_win_is_valid(windowId) then
    print("[ERROR] bloat.nvim: Unable to rename as there are no open windows!")
    return
  end

  ---@type vim.api.keyset.win_config
  local oldConfig = vim.api.nvim_win_get_config(windowId)
  oldConfig["title"][1][1] = " " .. opts.args .. " "
  vim.api.nvim_win_set_config(windowId, oldConfig)

  local newFileName = GetFileName(opts.args)
  local oldFileName = vim.api.nvim_buf_get_name(lastBufNr)
  vim.api.nvim_buf_set_name(lastBufNr, newFileName)
  vim.api.nvim_buf_call(lastBufNr, function()
    vim.cmd("write")
  end)
  vim.uv.fs_unlink(oldFileName)

  bufNrNameMap[lastBufNr] = { opts.args, newFileName }
end

function M.setup(opts)
  OPTS = opts

  Init()

  vim.api.nvim_create_user_command("BloatCreate", Create, { nargs = "?" })
  vim.api.nvim_create_user_command("BloatOpen", Open, {
    nargs = 1,
    complete = function(_, _, _)
      ---@type string[]
      local values = {}
      for _, v in pairs(bufNrNameMap) do
        table.insert(values, v[1])
      end

      return values
    end,
  })
  vim.api.nvim_create_user_command("BloatClose", Close, {})
  vim.api.nvim_create_user_command("BloatToggle", Toggle, {})
  vim.api.nvim_create_user_command("BloatRename", Rename, { nargs = 1 })
end

return M
