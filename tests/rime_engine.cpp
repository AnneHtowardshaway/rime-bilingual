// SPDX-License-Identifier: GPL-3.0-or-later
// 使用鼠须管或小狼毫携带的真实 librime，在隔离目录中编译并验证候选。
#include "rime_api.h"
#ifdef _WIN32
#include <windows.h>
#include <filesystem>
#else
#include <dlfcn.h>
#endif
#include <atomic>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

static std::atomic<bool> deployment_failed{false};
static void notify(void*, RimeSessionId, const char* type, const char* value) {
  if (std::string(type) == "deploy" && std::string(value) == "failure")
    deployment_failed = true;
}
static void require(bool condition, const std::string& message) {
  if (!condition) throw std::runtime_error(message);
}
using Candidates = std::vector<std::pair<std::string, std::string>>;
static Candidates query(RimeApi* api, RimeSessionId session, const std::string& code) {
  api->clear_composition(session);
  api->simulate_key_sequence(session, code.c_str());
  RIME_STRUCT(RimeContext, context);
  require(api->get_context(session, &context), "无法读取候选：" + code);
  Candidates result;
  for (int i = 0; i < context.menu.num_candidates; i++) {
    auto& candidate = context.menu.candidates[i];
    result.emplace_back(candidate.text, candidate.comment ? candidate.comment : "");
  }
  api->free_context(&context);
  return result;
}
static int run(int argc, char** argv) {
  if (argc < 3) { std::fprintf(stderr, "用法：rime-engine USER_DIR SCHEMA [INPUT]\n"); return 2; }
  RimeApi* api = nullptr;
  const char* stage = "load engine";
  try {
#ifdef _WIN32
    const wchar_t* installation = _wgetenv(L"RIME_TEST_WEASEL_DIR");
    require(installation && *installation, "RIME_TEST_WEASEL_DIR 未设置");
    std::filesystem::path directory(installation);
    auto library = LoadLibraryW((directory / L"rime.dll").c_str());
    require(library, "无法加载 Windows rime.dll");
    auto entry = reinterpret_cast<RimeApi* (*)()>(GetProcAddress(library, "rime_get_api"));
    std::string shared = (directory / L"data").u8string();
    const char* frontend = "weasel.yaml";
#else
    const std::string frameworks = "/Library/Input Methods/Squirrel.app/Contents/Frameworks";
    void* library = dlopen((frameworks + "/librime.1.dylib").c_str(), RTLD_NOW | RTLD_GLOBAL);
    require(library, "无法加载 librime");
    for (auto name : {"lua", "octagram", "predict"})
      require(dlopen((frameworks + "/rime-plugins/librime-" + name + ".dylib").c_str(),
                     RTLD_NOW | RTLD_GLOBAL), "无法加载插件：" + std::string(name));
    auto entry = reinterpret_cast<RimeApi* (*)()>(dlsym(library, "rime_get_api"));
    std::string shared = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport";
    const char* frontend = "squirrel.yaml";
#endif
    require(entry, "librime 缺少 API 入口");
    api = entry();
    RIME_STRUCT(RimeTraits, traits);
    traits.shared_data_dir = shared.c_str();
    traits.user_data_dir = argv[1];
    traits.app_name = "rime.bilingual-test";
    traits.min_log_level = 2;
    const char* modules[] = {"default", "lua", "grammar", nullptr};
    traits.modules = modules;
    traits.log_dir = "";
#ifdef _WIN32
    traits.prebuilt_data_dir = shared.c_str();
#endif
    stage = "setup";
    api->setup(&traits);
    api->set_notification_handler(notify, nullptr);
    stage = "initialize";
    api->initialize(nullptr);
    // 查询模式不重新部署，可检查已编译的真实安装副本。
    stage = "compile schemas";
    if (argc == 3 && api->start_maintenance(True)) api->join_maintenance_thread();
    require(!deployment_failed, "Rime 方案编译失败，请查看隔离目录日志");
    stage = "compile frontend";
    if (argc == 3)
      require(api->deploy_config_file(frontend, "config_version"), "候选窗口配置编译失败");
    stage = "select schema";
    auto session = api->create_session();
    require(session, "无法创建会话");
    require(api->select_schema(session, argv[2]), "无法选择方案");
    api->set_option(session, "ascii_mode", False);
    stage = "query and commit";
    if (argc > 3) {
      auto candidates = query(api, session, argv[3]);
      std::printf("%s / %s\n", argv[2], argv[3]);
      for (size_t i = 0; i < candidates.size(); i++)
        std::printf("%zu. %s [%s]\n", i + 1, candidates[i].first.c_str(), candidates[i].second.c_str());
    } else {
      const std::pair<const char*, const char*> cases[] = {
        {"github", "GitHub"}, {"gitlab", "GitLab"}, {"docker", "Docker"},
        {"chatgpt", "ChatGPT"}, {"javascript", "JavaScript"}, {"typescript", "TypeScript"},
        {"python", "Python"}, {"vscode", "VS Code"}, {"openai", "OpenAI"},
        {"kubernetes", "Kubernetes"}, {"nginx", "Nginx"}, {"markdown", "Markdown"},
      };
      for (auto& item : cases) {
        auto candidates = query(api, session, item.first);
        size_t index = candidates.size() == 1 ? 0 : 1;
        require(!candidates.empty() && candidates[index].first == item.second,
                "第二候选不匹配：" + std::string(item.first));
        require(std::string(item.first) != "github" || index == 1, "GitHub 必须位于第二项");
        int count = 0;
        for (auto& candidate : candidates) if (candidate.first == item.second) count++;
        require(count == 1, "英文候选重复：" + std::string(item.first));
        std::printf("PASS %s / %s → %zu. %s\n", argv[2], item.first, index + 1, item.second);
      }
      // 选择第二候选必须提交完整英文，而不是部分编码或中文组句。
      query(api, session, "github");
      require(api->select_candidate_on_current_page(session, 1), "无法选择第二候选");
      RIME_STRUCT(RimeCommit, commit);
      require(api->get_commit(session, &commit), "第二候选没有提交文本");
      std::string committed = commit.text;
      api->free_commit(&commit);
      require(committed == "GitHub", "第二候选提交错误：" + committed);
      query(api, session, "github");
      api->process_key(session, '2', 0);
      RIME_STRUCT(RimeCommit, numbered_commit);
      require(api->get_commit(session, &numbered_commit), "数字 2 没有提交候选");
      committed = numbered_commit.text;
      api->free_commit(&numbered_commit);
      require(committed == "GitHub", "数字 2 提交错误：" + committed);
      auto chinese = query(api, session, "kaifa");
      require(!chinese.empty() && chinese[0].first == "开发", "中文首选变化");
      require(chinese[0].second.find("develop") != std::string::npos, "中文英文释义缺失");
      api->set_option(session, "bilingual_gloss_disabled", True);
      chinese = query(api, session, "kaifa");
      require(chinese[0].second.find("develop") == std::string::npos, "释义开关失效");
      api->set_option(session, "internet_english_disabled", True);
      auto disabled = query(api, session, "github");
      require(disabled.size() < 2 || disabled[1].second != "代码托管", "英文开关失效");
      if (std::string(argv[2]) == "luna_pinyin_simp") {
        api->set_option(session, "internet_english_disabled", False);
        auto prefixed = query(api, session, ";github");
        require(!prefixed.empty() && prefixed[0].first == "GitHub", "分号入口回归");
        prefixed = query(api, session, "vvgithub");
        require(!prefixed.empty() && prefixed[0].first == "GitHub", "vv 入口回归");
      }
      std::printf("PASS %s：选择、数字键提交、中文释义、开关与旧入口\n", argv[2]);
    }
    api->destroy_session(session);
    api->finalize();
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "FAIL [%s] %s\n", stage, error.what());
    if (api) api->finalize();
    return 1;
  }
}

#ifdef _WIN32
int wmain(int argc, wchar_t** wide_argv) {
  SetConsoleOutputCP(CP_UTF8);
  std::vector<std::string> arguments;
  for (int i = 0; i < argc; i++) {
    int size = WideCharToMultiByte(CP_UTF8, 0, wide_argv[i], -1, nullptr, 0, nullptr, nullptr);
    std::string value(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide_argv[i], -1, value.data(), size, nullptr, nullptr);
    value.pop_back();
    arguments.push_back(std::move(value));
  }
  std::vector<char*> argv;
  for (auto& value : arguments) argv.push_back(value.data());
  return run(argc, argv.data());
}
#else
int main(int argc, char** argv) { return run(argc, argv); }
#endif
