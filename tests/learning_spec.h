// SPDX-License-Identifier: GPL-3.0-or-later
// 只在隔离用户目录中测试，不读写使用者的学习记录。
static int candidate_index(RimeApi* api, RimeSessionId session,
                           const std::string& text) {
  RimeCandidateListIterator iterator{};
  if (!api->candidate_list_begin(session, &iterator)) return -1;
  int found = -1;
  while (api->candidate_list_next(&iterator)) {
    if (text == iterator.candidate.text) { found = iterator.index; break; }
    if (iterator.index >= 512) break;
  }
  api->candidate_list_end(&iterator);
  return found;
}

static void select_text(RimeApi* api, RimeSessionId session,
                        const std::string& text) {
  int index = candidate_index(api, session, text);
  require(index >= 0, "缺少待选择的候选：" + text);
  require(api->select_candidate(session, index), "无法选择候选：" + text);
}

static std::string committed_text(RimeApi* api, RimeSessionId session) {
  RIME_STRUCT(RimeCommit, commit);
  if (!api->get_commit(session, &commit)) return "";
  std::string text = commit.text;
  api->free_commit(&commit);
  return text;
}

static void learning_spec(RimeApi* api, RimeSessionId& session, const char* schema) {
  api->set_option(session, "internet_english_disabled", False);
  api->set_option(session, "bilingual_gloss_disabled", False);
  auto custom = query(api, session, "xinglangongzuoshi");
  require(!custom.empty() && custom[0].first == "星澜工作室", "私人短语未优先显示");
  select_text(api, session, "星澜工作室");
  require(committed_text(api, session) == "星澜工作室", "私人短语上屏错误");

  // 完整拼音内逐字选词：第一次不能已有整词，选首字后不能提前上屏。
  query(api, session, "lanxu");
  require(candidate_index(api, session, "岚栩") == -1, "造词测试必须使用未学习的新词");
  select_text(api, session, "岚");
  require(committed_text(api, session).empty(), "首字提前上屏，未形成一次完整组词");
  select_text(api, session, "栩");
  require(committed_text(api, session) == "岚栩", "逐字组词上屏错误");
  query(api, session, "lanxu");
  require(candidate_index(api, session, "岚栩") >= 0, "组出的新词没有成为候选");

  query(api, session, "shishi");
  std::string frequent;
  int before = -1;
  for (auto word : {"试试", "实施", "事实", "实时"}) {
    int index = candidate_index(api, session, word);
    if (index > 0) { frequent = word; before = index; break; }
  }
  require(before > 0, "词频测试需要非首位候选");
  for (int i = 0; i < 16; i++) {
    select_text(api, session, frequent);
    require(committed_text(api, session) == frequent, "学习时选词上屏错误");
    query(api, session, "shishi");
  }
  int after = candidate_index(api, session, frequent);
  require(after >= 0 && after < before, "重复选词没有提升优先级");
  std::printf("PASS %s：新词学习、私人短语、%s 词频提权 %d → %d\n", schema, frequent.c_str(), before + 1, after + 1);

  if (std::string(schema) == "wanxiang") {
    query(api, session, "shishi");
    int index = candidate_index(api, session, "石狮");
    require(index > 0, "置顶测试需要非首位候选");
    require(api->highlight_candidate(session, index), "无法高亮待置顶候选");
    require(api->simulate_key_sequence(session, "{Control+p}"), "置顶快捷键未处理");
    auto pinned = query(api, session, "shishi");
    require(pinned[0].first == "石狮", "Control+p 置顶未生效");
  }

  // 销毁并重建输入会话，确认新词与手动排序可重新读取。
  api->clear_composition(session);
  api->destroy_session(session);
  session = api->create_session();
  require(session && api->select_schema(session, schema), "无法重建学习测试会话");
  api->set_option(session, "ascii_mode", False);
  query(api, session, "lanxu");
  require(candidate_index(api, session, "岚栩") >= 0, "新会话未保留自造词");
  if (std::string(schema) == "wanxiang") {
    auto pinned = query(api, session, "shishi");
    require(pinned[0].first == "石狮", "新会话未保留手动置顶");
    require(api->simulate_key_sequence(session, "{Control+l}"), "重置快捷键未处理");
    auto reset = query(api, session, "shishi");
    require(reset[0].first != "石狮", "Control+l 未撤销手动置顶");
    std::printf("PASS %s：置顶、跨会话保留与重置\n", schema);
  }
}

static void learning_persistence_spec(RimeApi* api, RimeSessionId session, const char* schema) {
  query(api, session, "lanxu");
  require(candidate_index(api, session, "岚栩") >= 0, "重启引擎后未保留自造词");
  std::printf("PASS %s：重启引擎后仍保留自造词\n", schema);
}
