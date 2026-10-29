-- SPDX-License-Identifier: GPL-3.0-or-later
-- 仅在当前段的完整英文编码精确命中时插入第二候选，不参与拼音组句。
local M = {}
local words_cache = nil
local cached_dir = nil
local cached_open = nil

local function lookup_word(data, target)
  if data == "" or type(target) ~= "string" or target == "" then
    return nil
  end
  local lo = 1
  local hi = #data
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local line_start = mid
    while line_start > lo and data:byte(line_start - 1) ~= 10 do
      line_start = line_start - 1
    end
    local line_end = data:find("\n", line_start, true) or (#data + 1)
    local tab1 = data:find("\t", line_start, true)
    if not tab1 or tab1 >= line_end then
      return nil
    end
    local code = data:sub(line_start, tab1 - 1)
    if code == target then
      local rest = data:sub(tab1 + 1, line_end - 1)
      local tab2 = rest:find("\t", 1, true)
      if tab2 then
        return { text = rest:sub(1, tab2 - 1), comment = rest:sub(tab2 + 1) }
      end
      return { text = rest, comment = "" }
    elseif code < target then
      lo = line_end + 1
    else
      hi = line_start - 2
    end
  end
  return nil
end

local function make_words_view(raw_data)
  if raw_data == "" then
    return {}
  end
  return setmetatable({ [false] = true }, {
    __index = function(_, code)
      return lookup_word(raw_data, code)
    end,
    __pairs = function()
      local next_line = raw_data:gmatch("[^\n]+")
      return function()
        local line = next_line()
        if not line then
          return nil
        end
        local code, text, comment = line:match("^([a-z]+)\t([^\t]+)\t?(.*)$")
        if not code then
          return nil
        end
        return code, { text = text, comment = comment }
      end
    end,
  })
end

local function load_words()
  local dir = rime_api.get_user_data_dir()
  if words_cache ~= nil and cached_dir == dir and cached_open == io.open then
    return words_cache
  end

  local seen = {}
  local entries = {}
  local all_loaded = true
  for _, name in ipairs({ "internet-english.tsv", "programming-english.tsv" }) do
    local filename = dir .. "/data/" .. name
    local file = io.open(filename, "r")
    if not file then
      all_loaded = false
      log.error("[internet_english_filter] 无法读取词表: " .. filename)
    else
      for line in file:lines() do
        line = line:gsub("^\239\187\191", ""):gsub("\r$", "")
        local code, text, comment = line:match("^([a-z]+)\t([^\t]+)\t?(.*)$")
        if code and not seen[code] then
          seen[code] = true
          entries[#entries + 1] = code .. "\t" .. text .. "\t" .. (comment or "")
        end
      end
      file:close()
    end
  end

  table.sort(entries, function(a, b)
    local ca = a:sub(1, (a:find("\t", 1, true) or 1) - 1)
    local cb = b:sub(1, (b:find("\t", 1, true) or 1) - 1)
    return ca < cb
  end)
  local view = make_words_view(table.concat(entries, "\n"))
  if all_loaded then
    words_cache = view
    cached_dir = dir
    cached_open = io.open
  end
  return view
end

function M.init(env)
  env.words = load_words()
end

function M.fini(env)
  env.words = nil
end

function M.func(input, env)
  local context = env.engine.context
  local segment = context.composition:back()
  local input_end = #context.input
  if context:get_option("ascii_mode")
      or context:get_option("internet_english_disabled")
      or not segment or segment.start < 0 or segment.start >= segment._end
      or segment._end ~= input_end or context.caret_pos ~= input_end
      or not segment:has_tag("abc") then
    for candidate in input:iter() do yield(candidate) end
    return
  end

  -- 中文前段已选但尚未上屏时，当前段的坐标仍指向整串原始编码。
  local start, finish = segment.start, segment._end
  local code = context.input:sub(start + 1, finish)
  local word = env.words[code]
  if not word then
    for candidate in input:iter() do yield(candidate) end
    return
  end

  local inserted = false
  for candidate in input:iter() do
    -- 丢弃同词的上游候选，避免其权重或用户调频改变固定位置。
    if candidate.text:lower() == word.text:lower()
        and candidate.start == start and candidate._end == finish then
      -- 固定位置的候选统一在下方生成。
    else
      yield(candidate)
      if not inserted then
        local english = Candidate("internet_english", start, finish,
          word.text, word.comment)
        english.preedit = code
        yield(english)
        inserted = true
      end
    end
  end
  -- 没有其他候选时仍允许直接输出英文。
  if not inserted then
    local english = Candidate("internet_english", start, finish, word.text, word.comment)
    english.preedit = code
    yield(english)
  end
end

return M
