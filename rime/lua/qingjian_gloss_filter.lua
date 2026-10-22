-- 为中文候选追加英文词性和译词。
-- 释义在组件初始化时一次性载入，逐键查询只进行哈希表查找。

local M = {}
local glossary_cache = nil

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function load_glossary(max_senses)
  glossary_cache = glossary_cache or {}
  if glossary_cache[max_senses] ~= nil then
    return glossary_cache[max_senses]
  end

  local glossary = {}
  local path = rime_api.get_user_data_dir() .. "/data/qingjian-glossary-en.tsv"
  local file, open_error = io.open(path, "r")

  if file == nil then
    log.error("[qingjian_gloss_filter] 无法读取释义表: " .. path .. "; " .. tostring(open_error))
    glossary_cache[max_senses] = glossary
    return glossary
  end

  for line in file:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local fields = {}
      for field in line:gmatch("[^\t]+") do
        fields[#fields + 1] = trim(field)
      end

      local word = fields[1]
      if word ~= nil and word ~= "" and fields[2] ~= nil then
        local senses = { fields[2] }
        for index = 3, max_senses + 1 do
          if fields[index] ~= nil and fields[index] ~= "" then
            senses[#senses + 1] = fields[index]
          end
        end
        glossary[word] = table.concat(senses, " · ")
      end
    end
  end

  file:close()
  glossary_cache[max_senses] = glossary
  log.info("[qingjian_gloss_filter] 已载入离线中英释义表")
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

      -- ShadowCandidate 保留原候选的输入范围、质量和学习关系，仅覆盖显示注释。
      yield(ShadowCandidate(candidate, candidate.type, "", comment))
    end
  end
end

return M
