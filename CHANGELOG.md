# Zephira Changelog

## [0.1.2]

### Fixed
- Release workflow now publishes multi-architecture Docker images (`linux/amd64` and `linux/arm64`). Previous releases only built `linux/amd64`, which prevented the sandbox from launching on Apple Silicon and other arm64 hosts.

## [0.1.1]

### Fixed
- Published gem no longer includes `Gemfile` / `Gemfile.lock`, which previously caused Bundler to crash when invoking `zephira` from a CWD that resolved to the installed gem's directory tree.

## [0.1.0]

### Added
- Concurrent execution of read-only tool calls within a single model turn (`web_search`, `read_file`, `code_search`, `list_directory`, `memory_read`, `memory_list`). Mutating tools still run sequentially in declared order.
- `Tools::BaseTool.read_only?` class method — tools opt in by overriding it. Default is `false`.
- `Zephira::Tokens` module — single token-estimator shared by `History` and `Agent`.
- `Zephira::Agent::Status` extracted to its own file.
- `Zephira::Tools::MemoryStore` shared helper backing the four memory tools.
- Per-model `backend` override on `BaseModel` so future provider classes can be added without forking the inference loop.

### Changed
- Renamed `/models` slash command to `/model`.
- `Agent#run_loop` decomposed into focused helpers (`print_intro`, `render_status_bar`, `process_user_message`, `run_inference_with_spinner`, etc.).
- Cached `uname -a` and `pwd` at agent init instead of shelling out per request.
- Inference loop uses iteration instead of recursion for tool-call chains; max-iter guards become trivial to add.
- Memory tools now load YAML via `YAML.safe_load_file`.
- Backend `agent` is passed per call rather than held as an ivar; rescue paths nil-guard the agent.
- Debug toggle moved from raw `ENV["DEBUG"]` to `Config.read("ZEPHIRA_DEBUG")` for consistency.
- `code_search` tool uses POSIX `command -v` instead of `which`.
- Spinner elapsed-time updates now go through the public `TTY::Spinner#update` API instead of reaching into private `@tokens` state.
- `update_file` now allows empty content (declarative `allow_empty: true` is now the single source of truth).

### Fixed
- JSON parse failures on tool arguments now log via `agent.logger.error` with the raw payload instead of being silently swallowed.

### Tests
- Added thread-safe stdout/stderr silencer in `spec_helper` (`:show_output` opt-out).
- Added default `Config.read` stub in `spec_helper` (`:real_config` opt-out).
- Broadened error-path coverage for file tools and `Agent::Status`.
- Suite: 422 examples, 0 failures, ~96% line coverage.

## 0.1.0

In the beginning...
