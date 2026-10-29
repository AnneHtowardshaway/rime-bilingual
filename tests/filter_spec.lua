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
local loaded = environment("github")
english.init(loaded)
local function run(code, texts, options, change)
  local env, segment = environment(code, options)
  env.words = loaded.words
  if change then change(env.engine.context, segment) end
  local candidates = {}
  for _, text in ipairs(texts) do
    candidates[#candidates + 1] = type(text) == "table" and text
      or Candidate("original", segment.start, segment._end, text, "")
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
for _, item in ipairs({ { "zai", "Z.ai" }, { "mergerequest", "Merge Request" },
    { "gofmtprintf", "fmt.Printf" }, { "rusthashmap", "HashMap" },
    { "serdejson", "serde_json" }, { "promiseallsettled", "Promise.allSettled" },
    { "tsreadonlytype", "Readonly" }, { "pyasynciogather", "asyncio.gather" },
    { "javacompletablefuture", "CompletableFuture" } }) do
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
-- 前段中文已选但尚未上屏：只处理当前完整英文段，并保留整串编码中的坐标。
local function selected_prefix(_, segment) segment.start = 6 end
result = run("woyonggithub", { "Git湖北", "GitHub", "github", "Git" }, nil, selected_prefix)
equal(#result, 3); equal(result[1].text, "Git湖北"); equal(result[2].text, "GitHub")
equal(result[2].start, 6); equal(result[2]._end, 12); equal(result[2].preedit, "github")
equal(result[3].text, "Git")
for _, item in ipairs({ { "docker", "Docker" }, { "gofmtprintf", "fmt.Printf" },
    { "mergerequest", "Merge Request" }, { "serdejson", "serde_json" } }) do
  result = run("woyong" .. item[1], { "原候选", item[2]:lower(), "后续候选" }, nil, selected_prefix)
  equal(#result, 3); equal(result[2].text, item[2])
  equal(result[2].start, 6); equal(result[2]._end, 6 + #item[1])
  equal(result[2].preedit, item[1])
end
result = run("woyonggithub", { "GitHub", "github" }, nil, selected_prefix)
equal(#result, 1); equal(result[1].text, "GitHub")
equal(result[1].start, 6); equal(result[1]._end, 12); equal(result[1].preedit, "github")
result = run("woyonggithub", {}, nil, selected_prefix)
equal(#result, 1); equal(result[1].start, 6); equal(result[1]._end, 12)
-- 同文本但不同范围的上游候选不能误删。
local earlier = Candidate("original", 0, 6, "GitHub", "")
result = run("woyonggithub", { earlier, "GitHub", "github" }, nil, selected_prefix)
equal(#result, 2); equal(result[1], earlier); equal(result[2].start, 6)
for _, code in ipairs({ "woyonggithu", "woyonggithubx", "woyongGitHub",
    "woyonggithub.com", "woyonggithub/path" }) do
  equal(#run(code, { "原候选" }, nil, selected_prefix), 1)
end
for _, option in ipairs({ "ascii_mode", "internet_english_disabled" }) do
  equal(#run("woyonggithub", { "原候选" }, { [option] = true }, selected_prefix), 1)
end
equal(#run("woyonggithub", { "原候选" }), 1)
equal(#run("woyonggithub", { "原候选" }, nil, function(ctx, seg)
  seg.start = 6; ctx.caret_pos = 10
end), 1)
equal(#run("woyonggithub", { "原候选" }, nil, function(_, seg)
  seg.start = 6; seg._end = 11
end), 1)
equal(#run("woyonggithub", { "原候选" }, nil, function(_, seg)
  seg.start = 6; seg.has_tag = function(_, tag) return tag ~= "abc" end
end), 1)
equal(#run("https://github", { "原候选" }, nil, function(_, seg)
  seg.start = 8; seg.has_tag = function() return false end
end), 1)
equal(#run("github", { "原候选" }, nil, function(ctx)
  ctx.composition.back = function() return nil end
end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg) seg.start = -1 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg) seg.start = 6 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg) seg._end = 7 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg) seg._end = 3 end), 1)
equal(#run("github", { "原候选" }, nil, function(ctx) ctx.caret_pos = 3 end), 1)
equal(#run("github", { "原候选" }, nil, function(_, seg)
  seg.has_tag = function() return false end
end), 1)
local env = environment("github")
english.init(env)
local seen = {}
for _, name in ipairs({ "internet-english.tsv", "programming-english.tsv" }) do
  for line in io.lines(root .. "/rime/data/" .. name) do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local code, text, comment = line:match("^([a-z]+)\t([^\t]+)\t([^\t]+)$")
      assert(code and text and comment, "词表格式不正确：" .. line)
      assert(not seen[code], "跨词表重复编码：" .. code)
      assert(text == text:match("^%s*(.-)%s*$"), "英文前后有空格：" .. code)
      seen[code] = true
    end
  end
end
local count = 0
for code, word in pairs(env.words) do
  result = run(code, { "原候选", word.text, "后续候选" })
  equal(result[2].text, word.text); equal(#result, 3)
  count = count + 1
end
local formatted = 0
package.loaded["wanxiang/super_english"] = { F = {
  init = function(env) env.format_initialized = true end,
  fini = function(env) env.format_initialized = false end,
  func = function(input)
    formatted = formatted + 1
    for candidate in input:iter() do yield(candidate) end
  end,
} }
local format = dofile(root .. "/rime/lua/bilingual_english_format.lua")
local format_env, format_segment = environment("github")
format.init(format_env)
equal(format_env.format_initialized, true)
for _, tag in ipairs({ "abc", "tech_english", "tech_english_vv" }) do
  format_segment.has_tag = function(_, value) return value == tag end
  output = {}
  local original = Candidate("table", 0, 6, "useState", "")
  format.func(stream({ original }), format_env)
  equal(output[1], original)
end
equal(formatted, 1)
format.fini(format_env)
equal(format_env.format_initialized, false)

local gloss = dofile(root .. "/rime/lua/qingjian_gloss_filter.lua")
local function run_gloss(maximum, disabled, text, compact)
  local env = environment("kaifa", {
    bilingual_gloss_disabled = disabled, bilingual_compact = compact,
  })
  env.engine.schema.config.get_int = function() return maximum end
  gloss.init(env)
  output = {}
  gloss.func(stream({ Candidate("original", 0, 5, text or "开发", "") }), env)
  return output[1].comment
end
equal(run_gloss(1, false), "v. develop")
equal(run_gloss(2, false), "v. develop · v. exploit")
equal(run_gloss(2, false, "开发", true), "v. develop")
equal(run_gloss(2, false, "检索增强生成", true), "n. retrieval-augmented gener…")
equal(run_gloss(2, false, "检索增强生成", false), "n. retrieval-augmented generation")
equal(run_gloss(2, true, "开发", true), "")
local compact_env = environment("ceshi", { bilingual_compact = true })
compact_env.compact_glossary = { ["测试"] = string.rep("译", 28) }
output = {}
gloss.func(stream({ Candidate("phrase", 0, 5, "测试", "原注释") }), compact_env)
equal(output[1].comment, "原注释  " .. string.rep("译", 28))
compact_env.compact_glossary["测试"] = string.rep("译", 29)
output = {}
gloss.func(stream({ Candidate("phrase", 0, 5, "测试", "") }), compact_env)
equal(output[1].comment, string.rep("译", 28) .. "…")
equal(output[1].text, "测试")
equal(run_gloss(2, true), "")
equal(run_gloss(1, false, "回归"), "n. regression")
equal(run_gloss(2, false, "回归"), "n. regression · v. return")
equal(run_gloss(2, false, "延迟"), "n. latency · v. delay")
equal(run_gloss(2, false, "实现"), "v. implement · v. realize")
equal(run_gloss(2, false, "回调"), "n. callback")
equal(run_gloss(2, false, "异步"), "adj. asynchronous")
for _, item in ipairs({ { "协程", "n. coroutine" }, { "单例", "n. singleton" },
    { "工作流", "n. workflow" }, { "智能体", "n. agent" },
    { "提示词", "n. prompt" }, { "闭包", "n. closure" },
    { "云原生", "adj. cloud-native" } }) do
  equal(run_gloss(2, false, item[1]), item[2])
end
equal(run_gloss(2, true, "回调"), "")
equal(run_gloss(2, false, "不存在的词条"), "")

-- 专业覆盖表必须有序且唯一；逐条检查二分查找和默认义项数量。
env = environment("glossary")
gloss.init(env)
local technical_count = 0
local previous_word = ""
for line in io.lines(root .. "/rime/data/technical-glossary-en.tsv") do
  if line ~= "" and line:sub(1, 1) ~= "#" then
    local word, rest = line:match("^([^\t]+)\t(.+)$")
    assert(word and rest and word > previous_word, "专业释义未排序或重复：" .. line)
    local senses = {}
    for sense in rest:gmatch("[^\t]+") do
      assert(sense == sense:match("^%s*(.-)%s*$"), "专业释义含多余空白：" .. word)
      assert(sense:match("^[a-z]+%. .+"), "专业释义缺少词性：" .. word)
      senses[#senses + 1] = sense
    end
    assert(#senses >= 1 and #senses <= 4, "专业释义数量不正确：" .. word)
    equal(env.glossary[word], table.concat(senses, " · ", 1, math.min(2, #senses)))
    previous_word = word
    technical_count = technical_count + 1
  end
end
assert(technical_count > 0, "专业释义表为空")
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
-- Windows 编辑器常用 UTF-8 BOM 和 CRLF；不能因此丢掉首条词或带入回车。
local real_open = io.open
local function mock_lines(files)
  io.open = function(path)
    local lines = files[path:match("/([^/]+)$")]
    if not lines then return nil, "mocked missing file" end
    if type(lines) == "string" then
      return { read = function() return lines end, close = function() end }
    end
    return {
      lines = function()
        local index = 0
        return function() index = index + 1; return lines[index] end
      end,
      close = function() end,
    }
  end
end
mock_lines({
  ["internet-english.tsv"] = { "\239\187\191github\tGitHub\t代码托管\r" },
  ["programming-english.tsv"] = {},
})
env = environment("github")
english.init(env)
equal(env.words.github.text, "GitHub"); equal(env.words.github.comment, "代码托管")
local fresh_gloss = dofile(root .. "/rime/lua/qingjian_gloss_filter.lua")
mock_lines({
  ["qingjian-glossary-en.tsv"] = "\239\187\191开发\tv. develop\tv. exploit\r\n",
  ["technical-glossary-en.tsv"] = "\239\187\191# 技术释义\r\n回调\tn. callback\tn. test two\tn. test three\tn. test four\tn. test five\r\n",
})
env = environment("kaifa")
fresh_gloss.init(env)
equal(env.glossary["开发"], "v. develop · v. exploit")
equal(env.glossary["回调"], "n. callback · n. test two")
env.engine.schema.config.get_int = function() return 0 end
fresh_gloss.init(env)
equal(env.glossary["回调"], "n. callback")
env.engine.schema.config.get_int = function() return 5 end
fresh_gloss.init(env)
equal(env.glossary["回调"], "n. callback · n. test two · n. test three · n. test four")
io.open = real_open

-- 资源暂时缺失不能把空词表永久缓存；下次初始化应能恢复。
fresh_gloss = dofile(root .. "/rime/lua/qingjian_gloss_filter.lua")
local real_error = log.error
local missing_count = 0
local missing_base, missing_technical = true, true
log.error = function() missing_count = missing_count + 1 end
io.open = function(path, mode)
  if (missing_base and path:match("/qingjian%-glossary%-en%.tsv$"))
      or (missing_technical and path:match("/technical%-glossary%-en%.tsv$")) then
    return nil, "simulated missing file"
  end
  return real_open(path, mode)
end
env = environment("glossary")
fresh_gloss.init(env)
equal(next(env.glossary), nil); equal(missing_count, 2)
missing_technical = false
fresh_gloss.init(env)
equal(env.glossary["回调"], "n. callback")
equal(env.glossary["开发"], nil)
missing_base = false
fresh_gloss.init(env)
equal(env.glossary["开发"], "v. develop · v. exploit")
io.open = real_open; log.error = real_error
fresh_gloss.init(env)
equal(env.glossary["开发"], "v. develop · v. exploit")
equal(env.glossary["㕮"], "v. chew")
equal(env.glossary["鿏"], "n. plow")
equal(env.glossary["你"], "pron. you")
equal(env.glossary["㿠"], "adj. bright")
equal(env.glossary["不存在的词条"], nil)
equal(env.glossary[""], nil)

-- 缺少专业表时仍显示青简原义；文件恢复后覆盖旧义，不能复用旧的合并视图。
fresh_gloss = dofile(root .. "/rime/lua/qingjian_gloss_filter.lua")
missing_technical = true
log.error = function() end
io.open = function(path, mode)
  if missing_technical and path:match("/technical%-glossary%-en%.tsv$") then
    return nil, "simulated missing technical file"
  end
  return real_open(path, mode)
end
fresh_gloss.init(env)
equal(env.glossary["回调"], "v. pullback")
equal(env.glossary["开发"], "v. develop · v. exploit")
missing_technical = false
fresh_gloss.init(env)
equal(env.glossary["回调"], "n. callback")
io.open = real_open; log.error = real_error

-- 模拟 librime-lua 每次按键销毁多个 LuaTranslation 时触发的全量 GC，防止常驻大表导致卡顿。
gloss = nil
loaded = nil
english.init(env)
collectgarbage("collect")
local heap_kb = collectgarbage("count")
assert(heap_kb < 10240, "Lua 常驻堆过大：" .. tostring(heap_kb) .. " KB")
local gc_start = os.clock()
for _ = 1, 20 do
  collectgarbage("collect")
end
local gc_elapsed_ms = (os.clock() - gc_start) * 1000
assert(gc_elapsed_ms < 15, "20 次全量 GC 耗时过长：" .. tostring(gc_elapsed_ms) .. " ms")
english.fini(env)
equal(env.words, nil)
fresh_gloss.fini(env)
equal(env.glossary, nil)
equal(env.compact_glossary, nil)
print("Lua 回归通过：" .. count .. " 个英文编码、" .. technical_count .. " 个专业释义、去重、范围、开关与释义配置")
