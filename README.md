# Zephira

A command-line AI coding assistant written in Ruby. Runs in your terminal, keeps per-project conversation history, and executes safely contained inside a Docker or Podman sandbox by default.

## Quickstart

1. Install Docker or Podman — required for the sandbox.
   - Docker: https://docs.docker.com/get-docker/
   - Podman: https://podman.io/getting-started/installation

2. Add your OpenAI API key to `~/.zephira.yml`:

   ```yaml
   ZEPHIRA_API_KEY: "sk-..."
   ```

3. Install the gem:

   ```sh
   gem install zephira
   ```

4. Run it from any project directory:

   ```sh
   zephira
   ```

## Features

- Interactive terminal chat loop with per-session token-budget tracking and automatic history compaction
- Built-in slash commands: `/help`, `/about`, `/model`, `/history`, `/compact`, `/clear`, `/reload`, `/bye`
- Plugin-style tool system — drop a file in `lib/zephira/tools/` and it is auto-loaded:
  - file I/O: `read_file`, `update_file`, `delete_file`, `list_directory`
  - search: `code_search` (ripgrep-backed), `web_search` (Brave Search API)
  - execution: `shell`, `http_request`
  - persistent memory: `memory_read`, `memory_write`, `memory_list`, `memory_delete`
- Concurrent execution of read-only tool calls in a single turn (mutating tools still run sequentially in declared order)
- Pluggable model + backend layer — register a new model by dropping a file in `lib/zephira/models/`; backends bind per model class
- OpenAI-compatible backend out of the box; structured to add provider-specific backends without forking the core loop
- Docker or Podman sandbox enabled by default; `--dangerously-skip-sandbox` to opt out
- Persistent session log + conversation history under `.zephira/` in each project
- ~95% line coverage on a focused RSpec suite

## CLI

```sh
zephira              # start in the current directory
zephira --help       # CLI help
zephira --version    # installed version
zephira --dangerously-skip-sandbox  # run without container isolation (your filesystem is exposed)
```

## Local development install

```sh
git clone https://github.com/aarongough/zephira.git
cd zephira
bundle install
```

Requirements: Ruby 3.2+, Bundler, Docker or Podman (for sandboxed execution).

## Configuration

Zephira reads configuration from:

- environment variables
- `.zephira.yml` in the current project
- `~/.zephira.yml` in your home directory

Environment variables take precedence.

Example configuration:

```yaml
ZEPHIRA_API_KEY: "openai_API_KEY_HERE"
ZEPHIRA_BRAVE_SEARCH_API_KEY: "your_brave_api_key_here"
```

## Supported configuration keys

- `ZEPHIRA_API_KEY` — API key for the selected LLM backend
- `ZEPHIRA_MODEL` — model name to use
- `ZEPHIRA_BASE_URL` — base URL for OpenAI-compatible APIs
- `ZEPHIRA_BACKEND` — backend adapter identifier
- `ZEPHIRA_BASE_IMAGE` — base container image for sandbox execution
- `ZEPHIRA_BRAVE_SEARCH_API_KEY` — required for the web search tool
- `ZEPHIRA_SANDBOX` — internal/advanced flag to disable sandboxing

## Sandbox behavior

By default, Zephira attempts to run inside a container for safer execution.

When sandboxing is enabled, Zephira re-executes itself inside Docker or Podman and mounts your current project into `/workspace`. This gives the agent access to the project while helping isolate it from the host system.

To keep files created or edited in `/workspace` owned by the host user instead of root, Zephira runs the sandboxed process as your current host UID/GID at container runtime.

Zephira also mounts your global config into a sandbox-specific home directory inside the container so the agent can read `~/.zephira.yml` and `~/.zephira/` without depending on `/root`.

Zephira prefers Docker when both Docker and Podman are available. If Docker is unavailable but Podman is available, Zephira uses Podman automatically.

If neither Docker nor Podman is available, Zephira exits with an error and explains how to proceed.

You can bypass sandboxing with:

```sh
zephira --dangerously-skip-sandbox
```

Use that only if you understand the risks.

## Interactive commands

Inside Zephira, you can use slash commands:

- `/help` — show available commands
- `/about` — show project information
- `/model` — list available models
- `/model set MODEL_NAME` — switch models for the current session
- `/history` — print conversation history
- `/compact` — manually compact the conversation history
- `/clear` — clear the screen
- `/reload` — re-execute the agent process to pick up local code changes (conversation history is preserved)
- `/bye` — exit the session

## Available models

This repository currently includes model definitions for:

- `gpt-4.1`
- `gpt-4.1-mini`
- `gpt-5.4`
- `gpt-5.5`
- `gpt-o4-mini`
- `claude-3.5-sonnet`
- `llama4`

The exact names available in the running app are determined by the model classes in `lib/zephira/models`.

## Built-in tools

Zephira includes tools for:

- `read_file`
- `update_file`
- `delete_file`
- `list_directory`
- `code_search`
- `shell`
- `http_request`
- `web_search`
- `memory_write`
- `memory_read`
- `memory_list`
- `memory_delete`

These tools allow the agent to inspect the project, modify files, run commands, query APIs, and maintain lightweight persistent memory.

## Project structure

```text
exe/                     Executable entrypoint
lib/zephira/             Core application code
lib/zephira/models/      Model definitions
lib/zephira/tools/       Tool implementations
lib/zephira/commands/    Slash commands
lib/zephira/completions/ Readline completions
spec/                    Test suite
Dockerfile               Sandbox/runtime image
```

## Development

Install dependencies:

```sh
bundle install
```

Run the test suite:

```sh
bundle exec rspec
```

Run linting:

```sh
bundle exec standardrb --fix
```

### Containerized development

For an isolated dev environment that mirrors the shipped sandbox image, the `bin/` directory provides helper scripts. All three rebuild the `zephira-dev` image first (Docker caches layers, so this is a no-op after the first run).

- `bin/docker-build` — build the `zephira-dev` image from the current working tree.
- `bin/docker-zephira` — launch Zephira inside the container, running against the mounted working tree (`bundle exec ruby exe/zephira`). Use this when iterating on the agent itself.
- `bin/docker-shell [command]` — start an interactive `bash` inside the container, or run an arbitrary command. Useful for running specs or linting against the containerized Ruby:

  ```sh
  bin/docker-shell                                # interactive shell
  bin/docker-shell 'bundle exec rspec'            # run the suite in-container
  bin/docker-shell 'bundle exec standardrb --fix' # lint in-container
  ```

Both runner scripts mount the current directory at `/workspace`, run as the host UID/GID, and mount `~/.zephira.yml` and `~/.zephira/` into the container so configuration and history persist across runs.

While inside a running Zephira session started this way, the `/reload` slash command re-executes the agent process — picking up edits to `lib/zephira/**` without rebuilding the image or losing conversation history (which is persisted to `.zephira/history.jsonl`). This is the fastest inner loop for iterating on agent code.

## Design goals

Zephira favors:

- clarity over complexity
- small, readable components
- hackability and extension
- realistic terminal-first workflows
- sandboxed local agent execution

It is best thought of as a lightweight coding assistant and a learning-oriented agent framework, not a full enterprise platform.

## Logging and history

Zephira stores session information under `.zephira/` in the current project directory, including logs and conversation history. This makes sessions project-local and easy to inspect.

## License

Released under the MIT License.

See:

```text
license.txt
```

## Author

Aaron Gough

Project home:
https://github.com/aarongough/zephira
