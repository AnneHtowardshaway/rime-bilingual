-- 在标准 Lua 或鼠须管捆绑的 Lua 运行时中执行。
local root = assert(os.getenv("RIME_TEST_ROOT"), "RIME_TEST_ROOT 未设置")
local output = {}
local function equal(actual, expected)
  assert(actual == expected, tostring(actual) .. " != " .. tostring(expected))
end
rime_api = { get_user_data_dir = function() return root .. "/rime" end }
log = { error = function(message) error(message) end, info = function() end }
Candidate = function(kind, start, finish, text, comment)
  return { type = kind, start = start, _end = finish, text = text, comment = comment,
    quality = 0,
    get_dynamic_type = function(self) return self._original and "Shadow" or "Simple" end,
    get_genuine = function(self) return self._original or self end }
end
ShadowCandidate = function(original, kind, text, comment)
  local shadow = Candidate(kind, original.start, original._end,
    text ~= "" and text or original.text, comment)
  shadow._original = original
  return shadow
end
yield = function(candidate) output[#output + 1] = candidate end
local function stream(candidates)
  return { iter = function()
    local index = 0
    return function() index = index + 1; return candidates[index] end
  end }
end
local function environment(code, options)
  local segment = { start = 0, _end = #code, has_tag = function() return true end }
  local context = {
    input = code, caret_pos = #code,
    get_option = function(_, name) return options and options[name] or false end,
    composition = { back = function() return segment end },
  }
  return { engine = { context = context,
    schema = { config = { get_int = function() return nil end } } } }, segment
end
local english = dofile(root .. "/rime/lua/internet_english_filter.lua")
local function run(code, texts, options, change)
  local env, segment = environment(code, options)
  english.init(env)
  if change then change(env.engine.context, segment) end
  local candidates = {}
  for _, text in ipairs(texts) do
    candidates[#candidates + 1] = Candidate("original", 0, #code, text, "")
  end
  output = {}
  english.func(stream(candidates), env)
  return output
end
local result = run("github", { "Git湖北", "GitHub", "Git", "github" })
equal(#result, 3); equal(result[1].text, "Git湖北"); equal(result[2].text, "GitHub")
equal(result[2].start, 0); equal(result[2]._end, 6); equal(result[3].text, "Git")
result = run("github", { "GitHub", "Git湖北", "Git" })
equal(result[1].text, "Git湖北"); equal(result[2].text, "GitHub")
equal(run("github", { "GitHub" })[1].text, "GitHub")
equal(run("github", {})[1].text, "GitHub")
for _, item in ipairs({ { "zai", "Z.ai" }, { "mergerequest", "Merge Request" } }) do
  result = run(item[1], { "原候选", item[2]:lower(), "后续候选" })
  equal(result[1].text, "原候选"); equal(result[2].text, item[2])
  equal(result[2]._end, #item[1]); equal(#result, 3)
  equal(#run(item[1], { "原候选" }, { internet_english_disabled = true }), 1)
end
for _, code in ipairs({ "githu", "githubx", "kaifa", "github.com", "GitHub",
    "za", "mergereques", "mergerequestx" }) do
  result = run(code, { "原候选" }); equal(#result, 1); equal(result[1].text, "原候选")
end
for _, option in ipairs({ "ascii_mode", "internet_english_disabled" }) do
  equal(#run("github", { "原候选" }, { [option] = true }), 1)
end
equal(#run("github", { "原候选" }, nil, function(_, seg) seg.start = 3 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg) seg._end = 3 end), 1)
equal(#run("github", { "原候选" }, nil, function(ctx) ctx.caret_pos = 3 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg)
  seg.has_tag = function() return false end
end), 1)
local env = environment("github")
english.init(env)
local seen = {}
for line in io.lines(root .. "/rime/data/internet-english.tsv") do
  if line ~= "" and line:sub(1, 1) ~= "#" then
    local code, text, comment = line:match("^([a-z]+)\t([^\t]+)\t([^\t]+)$")
    assert(code and text and comment, "词表格式不正确：" .. line)
    assert(not seen[code], "重复编码：" .. code)
    assert(text == text:match("^%s*(.-)%s*$"), "英文前后有空格：" .. code)
    seen[code] = true
  end
end
local count = 0
for code, word in pairs(env.words) do
  result = run(code, { "原候选", word.text, "后续候选" })
  equal(result[2].text, word.text); equal(#result, 3)
  count = count + 1
end
local gloss = dofile(root .. "/rime/lua/qingjian_gloss_filter.lua")
local function run_gloss(maximum, disabled)
  local env = environment("kaifa", { bilingual_gloss_disabled = disabled })
  env.engine.schema.config.get_int = function() return maximum end
  gloss.init(env)
  output = {}
  gloss.func(stream({ Candidate("original", 0, 5, "开发", "") }), env)
  return output[1].comment
end
equal(run_gloss(1, false), "v. develop")
equal(run_gloss(2, false), "v. develop · v. exploit")
equal(run_gloss(2, true), "")
-- 模拟简繁转换后的嵌套包装；注释必须保留简体显示和底层学习候选。
local original = Candidate("phrase", 0, 3, "嵐", "")
original.quality = 7
local converted = ShadowCandidate(original, "simplified", "岚", "")
local wrapped = ShadowCandidate(converted, "simplified", "", "lan")
wrapped.quality = 9
env = environment("lan")
gloss.init(env)
output = {}
gloss.func(stream({ wrapped }), env)
equal(output[1].text, "岚"); equal(output[1]:get_genuine(), original)
equal(output[1].quality, 9); equal(output[1].start, 0); equal(output[1]._end, 3)
equal(output[1].comment, "lan  n. storm")
print("Lua 回归通过：" .. count .. " 个英文编码、去重、范围、开关与释义配置")
