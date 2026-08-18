# Security and confidentiality

This setup does not include an AI plugin, telemetry collector, cloud file browser, or automatic agent startup. The `agent` pane is an ordinary local shell; you decide which tool to run and which authentication/account policy applies.

Code, diffs, Markdown, PNG, and SVG files are processed locally. Kitty renders images through its graphics protocol and ImageMagick performs local format conversion. Language servers and formatters run as local processes.

## Third-party code

Neovim plugins are executable code with the same file access as Neovim. They are sourced from public GitHub repositories and their exact commits are recorded in `config/nvim/lazy-lock.json`. Review lockfile changes before accepting plugin updates. Homebrew packages are not version-pinned and should be installed through your employer's approved package source when policy requires it.

The setup contacts the network when installing or explicitly updating Homebrew packages, plugins, parsers, language servers, or formatters. Normal editing and local image rendering do not require an upload service. A document that deliberately references a remote resource may still cause the relevant tool to fetch that resource; avoid remote links when working in a restricted environment.

Keep private paths, hostnames, certificates, environment variables, and tokens out of this public repository. Use the local override files documented in `README.md`.

## Reporting

Do not open a public issue containing secrets or proprietary code. Remove sensitive material and provide a minimal reproduction.
