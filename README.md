# dotfiles

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ascariandrea/dotfiles/master/install.sh | bash
```

Or, if already cloned:

```sh
./install.sh
```

## Agent skills

`agents/skills/` holds skills for opencode and Claude Code. `install.sh` symlinks
each one into `~/.config/opencode/skills/` (canonical) and `~/.claude/skills/`,
so edits made through either path land in this repo.

The skills are generic: per-machine values and secrets live in `~/.env`
(template: [`env.example`](env.example), `chmod 600`, never committed). Each
skill sources it itself (`set -a; . ~/.env; set +a`); it is not exported from
`.zshrc`.
