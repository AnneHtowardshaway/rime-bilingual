// SPDX-License-Identifier: GPL-3.0-or-later
// 逐项读取公开词表，确保新增词自动进入真实引擎回归范围。
static void vocabulary_spec(RimeApi* api, RimeSessionId session,
                            const char* directory, const char* schema) {
  int count = 0;
  for (auto name : {"internet-english.tsv", "programming-english.tsv"}) {
    std::ifstream file(std::filesystem::u8path(directory) / "data" / name);
    require(file.is_open(), "无法读取英文词表：" + std::string(name));
    std::string line;
    int file_count = 0;
    while (std::getline(file, line)) {
      if (line.empty() || line[0] == '#') continue;
      auto tab = line.find('\t');
      auto next = line.find('\t', tab + 1);
      require(tab != std::string::npos && next != std::string::npos, "词表格式不正确");
      auto code = line.substr(0, tab);
      auto text = line.substr(tab + 1, next - tab - 1);
      // 全量词表检查最终组合；下面的代表用例另行模拟逐键输入和数字选词。
      auto candidates = query(api, session, code, true);
      size_t position = candidates.size() == 1 ? 0 : 1;
      require(!candidates.empty() && candidates[position].first == text,
              "全量词表候选不匹配：" + code + " → " + text);
      int duplicates = 0;
      for (auto& candidate : candidates) if (candidate.first == text) duplicates++;
      require(duplicates == 1, "全量词表存在重复候选：" + code);
      file_count++; count++;
      if (file_count % 500 == 0) {
        std::printf("CHECK %s / %s: %d\n", schema, name, file_count);
        std::fflush(stdout);
      }
    }
    require(file_count > 0, "英文词表为空：" + std::string(name));
  }
  require(count > 0, "英文词表为空");
  std::printf("PASS %s：全量 %d 个英文编码的排序与去重\n", schema, count);
}

// 通过真实按键与提交验证专业英语；既测英文编码，也测中文拼音。
static void computer_english_spec(RimeApi* api, RimeSessionId session) {
  const char* cases[][2] = {
    {"abstraction", "abstraction"}, {"coroutine", "coroutine"},
    {"racecondition", "race condition"}, {"threadpool", "thread pool"},
    {"garbagecollection", "garbage collection"}, {"dependencyinjection", "dependency injection"},
    {"authorization", "authorization"}, {"throughput", "throughput"},
    {"latency", "latency"}, {"backpressure", "backpressure"},
    {"algorithm", "algorithm"}, {"suanfa", "algorithm"},
    {"datastructure", "data structure"}, {"shujujiegou", "data structure"},
    {"binarysearch", "binary search"}, {"erfenchazhao", "binary search"},
    {"binarytree", "binary tree"}, {"erchashu", "binary tree"},
    {"recursion", "recursion"}, {"digui", "recursion"},
    {"polymorphism", "polymorphism"}, {"duotai", "polymorphism"},
    {"inheritance", "inheritance"}, {"leijicheng", "inheritance"},
    {"encapsulation", "encapsulation"}, {"fengzhuang", "encapsulation"},
    {"concurrency", "concurrency"}, {"bingfa", "concurrency"},
    {"authentication", "authentication"}, {"shenfenrenzheng", "authentication"},
  };
  int checked = 0;
  for (const auto& item : cases) {
    auto candidates = query(api, session, item[0]);
    size_t position = candidates.size() == 1 ? 0 : 1;
    require(!candidates.empty() && candidates[position].first == item[1],
            "专业英语逐键候选错误：" + std::string(item[0]));
    require(api->process_key(session, '1' + position, 0), "专业英语数字选词失败");
    require(committed_text(api, session) == item[1], "专业英语完整上屏错误");
    for (auto prefix : {";", "vv"}) {
      query(api, session, std::string(prefix) + item[0]);
      select_text(api, session, item[1]);
      require(committed_text(api, session) == item[1], "专业入口上屏错误");
    }
    ++checked;
  }
  for (auto prefix : {";", "vv"}) {
    query(api, session, std::string(prefix) + "authenticat");
    select_text(api, session, "authentication");
    require(committed_text(api, session) == "authentication", "专业前缀补全错误");
  }
  std::printf("PASS 计算机英语：%d 个逐键/数字选词用例、60 个专用入口、2 个前缀补全\n", checked);
}

static void technical_glossary_spec(RimeApi* api, RimeSessionId session,
                                    const char* schema) {
  const char* cases[][3] = {
    {"huidiao", "回调", "n. callback"},
    {"yibu", "异步", "adj. asynchronous"},
    {"xiecheng", "协程", "n. coroutine"},
    {"gongzuoliu", "工作流", "n. workflow"},
    {"tishici", "提示词", "n. prompt"},
    {"zhinengti", "智能体", "n. agent"},
  };
  for (const auto& item : cases) {
    query(api, session, item[0]);
    int index = candidate_index(api, session, item[1]);
    require(index >= 0, "缺少专业词候选：" + std::string(item[1]));
    RimeCandidateListIterator iterator{};
    require(api->candidate_list_from_index(session, &iterator, index), "无法读取专业词候选");
    bool matched = api->candidate_list_next(&iterator)
      && iterator.candidate.comment
      && std::string(iterator.candidate.comment).find(item[2]) != std::string::npos;
    api->candidate_list_end(&iterator);
    require(matched, "专业词释义不匹配：" + std::string(item[1]));
  }
  std::printf("PASS %s：回调、异步、协程、工作流、提示词与智能体专业释义\n", schema);
}

static void mixed_english_spec(RimeApi* api, RimeSessionId session,
                               const char* schema) {
  const char* cases[][3] = {
    {"woyonggithub", "GitHub", "我用GitHub"},
    {"woyongalgorithm", "algorithm", "我用algorithm"},
    {"woyongsuanfa", "algorithm", "我用algorithm"},
    {"woyongdocker", "Docker", "我用Docker"},
    {"woyonggofmtprintf", "fmt.Printf", "我用fmt.Printf"},
    {"woyongserdejson", "serde_json", "我用serde_json"},
  };
  for (const auto& item : cases) {
    query(api, session, item[0]);
    select_text(api, session, "我用");
    require(committed_text(api, session).empty(), "混输前缀提前上屏");
    RIME_STRUCT(RimeContext, context);
    require(api->get_context(session, &context), "无法读取混输候选");
    bool matched = context.menu.num_candidates > 1
      && std::string(context.menu.candidates[1].text) == item[1];
    api->free_context(&context);
    require(matched, "当前段英文第二候选不匹配：" + std::string(item[0]));
    require(api->process_key(session, '2', 0), "混输数字选词未处理");
    require(committed_text(api, session) == item[2],
            "混输完整提交不匹配：" + std::string(item[0]));
  }
  std::printf("PASS %s：中文选词后接续技术英文、数字2完整提交与API符号保留\n", schema);
}
