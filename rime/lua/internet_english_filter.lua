-- SPDX-License-Identifier: GPL-3.0-or-later
-- 仅在完整英文编码精确命中时插入第二候选，不参与拼音组句。
local M = {}

function M.init(env)
  env.words = {}
  for _, name in ipairs({ "internet-english.tsv", "programming-english.tsv" }) do
    local filename = rime_api.get_user_data_dir() .. "/data/" .. name
    local file = io.open(filename, "r")
    if not file then
      log.error("[internet_english_filter] 无法读取词表: " .. filename)
    else
      for line in file:lines() do
        line = line:gsub("^\239\187\191", ""):gsub("\r$", "")
        local code, text, comment = line:match("^([a-z]+)\t([^\t]+)\t?(.*)$")
        if code and not env.words[code] then
          env.words[code] = { text = text, comment = comment }
        end
      end
      file:close()
    end
  end
end

function M.func(input, env)
  local context = env.engine.context
  local segment = context.composition:back()
  local code = context.input
  local word = env.words[code]
  if not word or context:get_option("ascii_mode")
      or context:get_option("internet_english_disabled")
      or not segment or segment.start ~= 0 or segment._end ~= #code
      or context.caret_pos ~= #code or not segment:has_tag("abc") then
    for candidate in input:iter() do yield(candidate) end
    return
  end

  local inserted = false
  for candidate in input:iter() do
    -- 丢弃同词的上游候选，避免其权重或用户调频改变固定位置。
    if candidate.text:lower() == word.text:lower()
        and candidate.start == 0 and candidate._end == #code then
      -- 固定位置的候选统一在下方生成。
    else
      yield(candidate)
      if not inserted then
        local english = Candidate("internet_english", 0, #code,
          word.text, word.comment)
        english.preedit = code
        yield(english)
        inserted = true
      end
    end
  end
  -- 没有其他候选时仍允许直接输出英文。
  if not inserted then
    yield(Candidate("internet_english", 0, #code, word.text, word.comment))
  end
end

return M
