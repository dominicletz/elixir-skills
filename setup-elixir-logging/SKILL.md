---
name: setup-elixir-logging
description: Configure rotated and compressed file logging for Elixir/Phoenix projects using :logger_std_h. Use when setting up production logging, configuring logger rotation, or when the user asks to add file logging to an Elixir project.
---

# Setup Elixir Logging

## Quick Start

When setting up file logging for an Elixir/Phoenix project, use the built-in `:logger_std_h` handler. It supports log rotation and compression out of the box without requiring external dependencies.

Add the following configuration to `config/runtime.exs` (typically inside the `if config_env() == :prod do` block):

```elixir
  # File logging with rotation via :logger_std_h (Logger boot config).
  # See https://hexdocs.pm/logger/Logger.html#module-configuration
  # and https://www.erlang.org/doc/apps/kernel/logger_std_h.html
  #
  # Ensure the log directory exists before boot (e.g. mkdir in unit file or release overlay).
  # LOG_FILE — absolute or relative path (default: $RELEASE_ROOT/log/app.log, else log/app.log)
  # LOG_MAX_BYTES — rotate when file exceeds this size (default: 10_485_760)
  # LOG_MAX_FILES — rotated archives to keep (default: 5); .N.gz when compress_on_rotate is true
  log_file =
    cond do
      path = System.get_env("LOG_FILE") -> path
      root = System.get_env("RELEASE_ROOT") -> Path.join([root, "log", "app.log"])
      true -> "log/app.log"
    end

  max_bytes =
    case Integer.parse(System.get_env("LOG_MAX_BYTES", "10485760")) do
      {n, _} when n > 0 -> n
      _ -> 10_485_760
    end

  max_files =
    case Integer.parse(System.get_env("LOG_MAX_FILES", "5")) do
      {n, _} when n >= 0 -> n
      _ -> 5
    end

  config :logger, :default_handler,
    config: [
      file: String.to_charlist(log_file),
      filesync_repeat_interval: 5000,
      file_check: 5000,
      max_no_bytes: max_bytes,
      max_no_files: max_files,
      compress_on_rotate: true
    ]
```

## Implementation Notes

1. **No external dependencies**: This uses Erlang's standard `:logger_std_h` which is included in OTP.
2. **String.to_charlist**: The `file` option must be a charlist, not a binary string.
3. **Directory creation**: The directory containing the log file must exist before the application starts. The logger will not create it automatically.
4. **Environment Variables**: The configuration uses environment variables to allow overriding the defaults in production without recompiling.
