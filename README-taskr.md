# taskr

A fast, minimal CLI for managing todo items from your terminal.

## Installation

```bash
npm install -g taskr
```

## Usage

### Add a task

```bash
taskr add "Write project documentation"
taskr add "Fix login bug" --priority high
```

### List tasks

```bash
taskr list
taskr list --filter pending
taskr list --filter done
```

### Mark a task as done

```bash
taskr done 3
taskr done --all
```

### Remove a task

```bash
taskr remove 3
taskr remove --done   # remove all completed tasks
```

## Configuration

taskr reads from `~/.taskrrc` (JSON):

```json
{
  "storage": "~/.taskr/tasks.json",
  "defaultPriority": "medium",
  "dateFormat": "YYYY-MM-DD",
  "colors": true
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `storage` | `~/.taskr/tasks.json` | Path to the tasks file |
| `defaultPriority` | `medium` | Default priority for new tasks (`low`, `medium`, `high`) |
| `dateFormat` | `YYYY-MM-DD` | Timestamp format for task creation |
| `colors` | `true` | Enable colored terminal output |

Override any option per-command with `--no-colors`, `--priority <level>`, etc.

## Contributing

1. Fork the repo and create a feature branch (`git checkout -b feature/my-change`).
2. Make your changes and add tests.
3. Ensure all checks pass: `npm test && npm run lint`.
4. Commit with a descriptive message: `feat: add recurring tasks support`.
5. Open a pull request against `main`.

Please follow [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages.

## License

MIT
