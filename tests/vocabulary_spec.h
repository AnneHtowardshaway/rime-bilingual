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
