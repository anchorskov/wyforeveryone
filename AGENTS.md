<!-- AGENTS.md -->
# Wyoming for Everyone

## Project Overview

- Project name: Wyoming for Everyone
- Project type: static site for Cloudflare Pages
- Primary workflow: local development in WSL, deployment with Wrangler

## Working Rules

- Use WSL-compatible bash commands for all shell instructions and automation.
- Prefer local project tools over global installs whenever a local tool is available.
- Be cautious and do not overwrite existing files unless it is necessary for the task.
- Treat this repository as a plain static site. Do not add frameworks or build tools unless the user explicitly asks for them.
- When creating or editing files, include a top comment with the relative path and file name when that file type supports comments.

## Deployment Guardrails

"Before creating a new Pages project, first verify whether wyforeveryone already exists in the authenticated Cloudflare account."

- If the `wyforeveryone` Pages project already exists, deploy to the existing Pages project instead of creating a new one.
- If Cloudflare authentication is missing or invalid, stop and clearly instruct the user to run `npx wrangler login`.
- Prefer deployment with the local project Wrangler via `npx wrangler`.
- Use Cloudflare Pages Direct Upload for this repository unless the user explicitly asks for a different deployment model.

## Contributor Notes

- Review this file before making deployment-related changes.
- Keep deployment steps practical, direct, and suitable for a local WSL workflow.
