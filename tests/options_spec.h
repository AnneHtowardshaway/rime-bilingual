// SPDX-License-Identifier: GPL-3.0-or-later
// 经由真实方案选单保存开关，覆盖新会话和引擎重启。
static void toggle_saved_option(RimeApi* api, RimeSessionId session,
                                const char* name, const char* label) {
  const bool before = api->get_option(session, name);
  api->clear_composition(session);
  require(api->simulate_key_sequence(session, "{F4}"), "无法打开方案选单");
  int index = candidate_index(api, session, label);
  if (index < 0) {
    // 选单仅含万象；第二项为上游默认折叠的开关列表。
    require(api->select_candidate(session, 1), "无法展开方案开关");
    index = candidate_index(api, session, label);
  }
  require(index >= 0, "方案选单缺少开关：" + std::string(label));
  require(api->select_candidate(session, index), "无法切换：" + std::string(label));
  require(bool(api->get_option(session, name)) != before,
          "开关没有切换：" + std::string(name));
}

static void require_bilingual_options(RimeApi* api, RimeSessionId session,
                                      bool disabled) {
  for (auto name : {"internet_english_disabled", "bilingual_gloss_disabled"})
    require(bool(api->get_option(session, name)) == disabled,
            "未保留开关状态：" + std::string(name));
  api->set_option(session, "ascii_mode", False);
  auto chinese = query(api, session, "kaifa");
  require(!chinese.empty(), "缺少中文候选");
  require((chinese[0].second.find("develop") == std::string::npos) == disabled,
          "已保存的释义状态未应用");
  auto english = query(api, session, "github");
  require(english.size() > 1, "缺少英文测试候选");
  require((english[1].second != "代码托管") == disabled,
          "已保存的英文候选状态未应用");
}

static void options_spec(RimeApi* api, RimeSessionId& session, const char* schema) {
  toggle_saved_option(api, session, "bilingual_compact", "伴学显示");
  auto compact = query(api, session, "kaifa");
  require(!compact.empty() && compact[0].first == "开发"
          && compact[0].second.find("develop") != std::string::npos
          && compact[0].second.find("exploit") == std::string::npos,
          "简洁显示未限制为一个义项");
  toggle_saved_option(api, session, "internet_english_disabled", "英文候选");
  toggle_saved_option(api, session, "bilingual_gloss_disabled", "英文释义");
  api->destroy_session(session);
  session = api->create_session();
  require(session && api->select_schema(session, schema), "无法重建开关测试会话");
  require_bilingual_options(api, session, true);
  require(api->get_option(session, "bilingual_compact"), "新会话未保留简洁显示");
  std::printf("PASS %s：新会话保留简洁显示、英文候选与释义关闭状态\n", schema);
}

static void options_persistence_spec(RimeApi* api, RimeSessionId& session,
                                     const char* schema) {
  require_bilingual_options(api, session, true);
  require(api->get_option(session, "bilingual_compact"), "重启引擎未保留简洁显示");
  toggle_saved_option(api, session, "internet_english_disabled", "关闭英文候选");
  toggle_saved_option(api, session, "bilingual_gloss_disabled", "关闭英文释义");
  auto compact = query(api, session, "kaifa");
  require(!compact.empty() && compact[0].second.find("exploit") == std::string::npos,
          "重新开启释义后简洁显示失效");
  toggle_saved_option(api, session, "bilingual_compact", "简洁显示");
  api->destroy_session(session);
  session = api->create_session();
  require(session && api->select_schema(session, schema), "无法重建开关测试会话");
  require_bilingual_options(api, session, false);
  require(!api->get_option(session, "bilingual_compact"), "新会话未保留伴学显示");
  auto study = query(api, session, "kaifa");
  require(!study.empty() && study[0].second.find("exploit") != std::string::npos,
          "伴学显示未恢复完整释义");
  std::printf("PASS %s：重启引擎保留简洁显示与开关，切回伴学后新会话恢复完整释义\n", schema);
}
