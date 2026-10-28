-- 为中文候选追加英文词性和译词。
-- 释义在组件初始化时一次性载入紧凑文本缓冲区，逐候选用二分查找避免海量 Lua 对象触发 GC 卡顿。

local M = {}
local glossary_cache = {}
local cached_raw_data = nil
local cached_path = nil
local cached_open = nil

local function trim(value)
  return (value:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function normalize_glossary(content)
  content = content:gsub("^\239\187\191", "")
  if content:find("\r", 1, true) then
    content = content:gsub("\r\n?", "\n")
  end
  while content:sub(1, 1) == "#" do
    local newline = content:find("\n", 1, true)
    content = newline and content:sub(newline + 1) or ""
  end
  if content:find("\n#", 1, true) then
    content = content:gsub("\n#[^\n]*", "")
  end
  if content:find("\n\n", 1, true) then
    content = content:gsub("\n+", "\n")
  end
  return (content:gsub("^\n+", ""):gsub("\n+$", ""))
end

local function format_senses(rest, max_senses)
  local senses = {}
  for field in rest:gmatch("[^\t]+") do
    field = trim(field)
    if field ~= "" then
      senses[#senses + 1] = field
      if #senses >= max_senses then
        break
      end
    end
  end
  if #senses == 0 then
    return nil
  end
  return table.concat(senses, " · ")
end

local function lookup_gloss(data, word, max_senses)
  if data == "" or type(word) ~= "string" or word == "" then
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
    local tab = data:find("\t", line_start, true)
    if not tab or tab >= line_end then
      return nil
    end
    local key = data:sub(line_start, tab - 1)
    if data:byte(line_start) <= 32 or data:byte(tab - 1) <= 32 then
      key = trim(key)
    end
    if key == word then
      return format_senses(data:sub(tab + 1, line_end - 1), max_senses)
    elseif key < word then
      lo = line_end + 1
    else
      hi = line_start - 2
    end
  end
  return nil
end

local function load_raw_data(path)
  if cached_raw_data ~= nil and cached_path == path and cached_open == io.open then
    return cached_raw_data
  end

  local file, open_error = io.open(path, "r")
  if file == nil then
    log.error("[qingjian_gloss_filter] 无法读取释义表: " .. path .. "; " .. tostring(open_error))
    return nil
  end

  local content
  if type(file.read) == "function" then
    content = file:read("*a") or ""
  else
    local lines = {}
    for line in file:lines() do
      lines[#lines + 1] = line
    end
    content = table.concat(lines, "\n")
  end
  file:close()

  cached_raw_data = normalize_glossary(content)
  cached_path = path
  cached_open = io.open
  glossary_cache = {}
  log.info("[qingjian_gloss_filter] 已载入离线中英释义表")
  return cached_raw_data
end

local function load_glossary(max_senses)
  local path = rime_api.get_user_data_dir() .. "/data/qingjian-glossary-en.tsv"
  local raw_data = load_raw_data(path)
  if raw_data == nil or raw_data == "" then
    return {}
  end

  if glossary_cache[max_senses] ~= nil then
    return glossary_cache[max_senses]
  end

  local glossary = setmetatable({ [false] = true }, {
    __index = function(_, word)
      return lookup_gloss(raw_data, word, max_senses)
    end,
  })
  glossary_cache[max_senses] = glossary
  return glossary
end

function M.init(env)
  local maximum = env.engine.schema.config:get_int("bilingual_gloss/max_senses") or 2
  env.glossary = load_glossary(math.max(1, math.min(4, maximum)))
end

function M.fini(env)
  env.glossary = nil
end

function M.func(input, env)
  if env.engine.context:get_option("bilingual_gloss_disabled") then
    for candidate in input:iter() do yield(candidate) end
    return
  end
  for candidate in input:iter() do
    local gloss = env.glossary[candidate.text]

    if gloss == nil then
      yield(candidate)
    else
      local comment = candidate.comment or ""
      if comment ~= "" then
        comment = comment .. "  " .. gloss
      else
        comment = gloss
      end

      -- librime 的学习入口只解包一层 ShadowCandidate。简繁转换等上游
      -- 过滤器已包装过候选时，不能再次嵌套，否则原生 Phrase 无法被识别。
      -- 保留显示文字（如「嵐」转成「岚」），直接包装最底层候选。
      local original = candidate
      while original:get_dynamic_type() == "Shadow"
          or original:get_dynamic_type() == "Uniquified" do
        original = original:get_genuine()
      end
      local annotated = ShadowCandidate(original, candidate.type, candidate.text, comment)
      annotated.quality = candidate.quality
      yield(annotated)
    end
  end
end

return M
