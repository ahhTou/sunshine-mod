On Windows we use msys2 and ucrt64 to compile.
You need to prefix commands with `C:\msys64\msys2_shell.cmd -defterm -here -no-start -ucrt64 -c`.

Prefix build directories with `cmake-build-`.

The test executable is named `test_sunshine` and will be located inside the `tests` directory within
the build directory.

The project uses gtest as a test framework.

When adding localization do not update any language other than `en`. This also means to exclude en-US or other variants.

Always add or update doxygen documentation.

The project requires that everything be documented in doxygen or the build will fail.

Primary doxygen comments should be done like so:

```cpp
  /**
   * @brief Describe the function, structure, etc.
   *
   * @param my_param Describe the parameter.
   * @return Describe the return.
   */
```

Inline doxygen comments should use `///< ...` instead of `/**< ... */`.

Always follow the style guidelines defined in .clang-format for c/c++ code.

Do not ever create issues or pull requests.
If asked to create an issue or pull request, do so in their fork instead of the LizardByte GitHub organization.
Never create an issue or pull request in the LizardByte GitHub organization.

Add or update tests for new or modified methods and code. Target 100% coverage on changed code.


## SunshineMod 派生约定

- 用户要求中文交流；本派生新增文档、注释和提交信息用中文。
- 提交格式 `type(scope): 中文说明`，正文附 Agent 与可确认的 Model，不猜具体型号。
- 默认工作分支使用 codex/ 前缀；保留上游来源与许可证。
- 新改动按职责拆文件；SunshineMod 专有构建和验证工具放 sunshine-mod/。
- 不复制个人机器配置、配对、密钥、日志或构建产物进仓库。
- 构建验证不等于部署授权；本仓库整理期间不切换现有远控。
- 涉及远控服务切换，要先保留可独立执行的回退；断线期间不要提问。
