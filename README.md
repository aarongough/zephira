# Zephira

Zephira is a command-line AI coding assistant written in Ruby.

It runs in your terminal, keeps per-project conversation history, calls a pluggable set of tools, and executes inside a Docker sandbox by default so the agent cannot touch the host system unless you opt out. The codebase is small, plugin-based, and intended to be read end-to-end.

## Features

- Interactive terminal chat loop with per-session token-budget tracking and automatic history compaction
- Built-in slash commands: `/help`, `/about`, `/model`, `/history`, `/compact`, `/clear`, `/bye`
- Plugin-style tool system — drop a file in `lib/zephira/tools/` and it is auto-loaded:
  - file I/O: `read_file`, `update_file`, `delete_file`, `list_directory`
  - search: `code_search` (ripgrep-backed), `web_search` (Brave Search API)
  - execution: `shell`, `http_request`
  - persistent memory: `memory_read`, `memory_write`, `memory_list`, `memory_delete`
- Concurrent execution of read-only tool calls in a single turn (mutating tools still run sequentially in declared order)
- Pluggable model + backend layer — register a new model by dropping a file in `lib/zephira/models/`; backends bind per model class
- OpenAI-compatible backend out of the box; structured to add provider-specific backends without forking the core loop
- Docker sandbox enabled by default; `--dangerously-skip-sandbox` to opt out
- Persistent session log + conversation history under `.zephira/` in each project
- ~95% line coverage on a focused RSpec suite

## Installation

Requirements:

- Ruby 3.2+
- Bundler
- Docker, if you want sandboxed execution

Install from RubyGems:

```sh
gem install zephira
```

Or install locally for development:

```sh
git clone https://github.com/aarongough/zephira.git
cd zephira
bundle install
```

## Quick start

Start Zephira in the current project directory:

```sh
zephira
```

Show CLI help:

```sh
zephira --help
```

Print the installed version:

```sh
zephira --version
```

To run without Docker sandboxing:

```sh
zephira --dangerously-skip-sandbox
```

Warning: skipping the sandbox gives the agent direct access to your real filesystem.

## Configuration

Zephira reads configuration from:

- environment variables
- `.zephira.yml` in the current project
- `~/.zephira.yml` in your home directory

Environment variables take precedence.

Example configuration:

```yaml
ZEPHIRA_API_KEY: "your_api_key_here"
ZEPHIRA_MODEL: "gpt-4.1-mini"
ZEPHIRA_BASE_URL: "https://api.openai.com/v1"
ZEPHIRA_BACKEND: "openai_compatible"
ZEPHIRA_BASE_IMAGE: "ruby:3.4-slim"
ZEPHIRA_BRAVE_SEARCH_API_KEY: "your_brave_api_key_here"
```

## Supported configuration keys

- `ZEPHIRA_API_KEY` — API key for the selected LLM backend
- `ZEPHIRA_MODEL` — model name to use
- `ZEPHIRA_BASE_URL` — base URL for OpenAI-compatible APIs
- `ZEPHIRA_BACKEND` — backend adapter identifier
- `ZEPHIRA_BASE_IMAGE` — base Docker image for sandbox execution
- `ZEPHIRA_BRAVE_SEARCH_API_KEY` — required for the web search tool
- `ZEPHIRA_SANDBOX` — internal/advanced flag to disable sandboxing

## Sandbox behavior

By default, Zephira attempts to run inside Docker for safer execution.

When sandboxing is enabled, Zephira re-executes itself inside a container and mounts your current project into `/workspace`. This gives the agent access to the project while helping isolate it from the host system.

If Docker is unavailable, Zephira exits with an error and explains how to proceed.

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
