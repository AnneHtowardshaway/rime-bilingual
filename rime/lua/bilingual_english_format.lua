-- 专用英文入口保持码表原文，不参与万象普通英文的自动空格与大小写格式化。
local english = require("wanxiang/super_english").F
local M = { init = english.init, fini = english.fini }

function M.func(input, env)
  local segment = env.engine.context.composition:back()
  if segment and (segment:has_tag("tech_english") or segment:has_tag("tech_english_vv")) then
    for candidate in input:iter() do yield(candidate) end
    return
  end
  english.func(input, env)
end

return M
