// SPDX-License-Identifier: GPL-3.0-or-later
// 以隔离词库中的真实逐键输入检查首选，失败时汇总全部语料及候选。
static void input_experience_spec(RimeApi* api, RimeSessionId session,
                                  const char* directory, const char* schema) {
  const auto filename = std::filesystem::u8path(directory) / "data" / "input-experience.tsv";
  std::ifstream file(filename);
  require(file.is_open(), "无法读取输入体验语料：" + filename.u8string());
  std::string line;
  int line_number = 0;
  int count = 0;
  int failures = 0;
  while (std::getline(file, line)) {
    ++line_number;
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (line_number == 1 && line.compare(0, 3, "\xef\xbb\xbf") == 0) line.erase(0, 3);
    if (line.empty() || line[0] == '#') continue;
    const auto tab = line.find('\t');
    require(tab != std::string::npos && tab > 0 && tab + 1 < line.size()
              && line.find('\t', tab + 1) == std::string::npos,
            "输入体验语料格式错误，第 " + std::to_string(line_number) + " 行");
    const std::string code = line.substr(0, tab);
    const std::string expected = line.substr(tab + 1);
    const auto candidates = query(api, session, code);
    ++count;
    if (candidates.empty() || candidates[0].first != expected) {
      ++failures;
      std::fprintf(stderr, "FAIL 输入体验第 %d 行：%s，期望首选「%s」，实际候选：",
                   line_number, code.c_str(), expected.c_str());
      if (candidates.empty()) std::fprintf(stderr, "<无>");
      for (size_t i = 0; i < candidates.size(); ++i)
        std::fprintf(stderr, "%s%zu. %s", i ? " / " : "", i + 1,
                     candidates[i].first.c_str());
      std::fprintf(stderr, "\n");
    }
  }
  require(count > 0, "输入体验语料为空");
  require(failures == 0, "输入体验回归失败：" + std::to_string(failures)
            + " / " + std::to_string(count));
  std::printf("PASS %s：%d 条整句、简拼及拼写容错体验语料\n", schema, count);
}
