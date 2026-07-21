#!/usr/bin/env bash
# Keeps AGENTS.md, CLAUDE.md, GEMINI.md identical, per AGENTS.md hard rule.
set -e
cp AGENTS.md CLAUDE.md
cp AGENTS.md GEMINI.md
echo "Synced AGENTS.md -> CLAUDE.md, GEMINI.md"
