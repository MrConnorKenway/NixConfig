# AGENTS

## Scope

- The plugin is intentionally implemented as a single file: `init.lua`.
- Keep the public surface minimal: `setup()`, `next_reference()`, `prev_reference()`, and `clear()`.
- Read-only diagnostics such as `:BeaconCacheHitRatio` and `:BeaconLspLatencyPrediction` should stay internal to `setup()` instead of expanding the exported Lua API.

## Core Behavior

- LSP highlighting uses `textDocument/documentHighlight`.
- Fallback mode is only for buffers without an attached highlight-capable LSP client.
- If an LSP client attaches but does not support `textDocument/documentHighlight`, switch to fallback immediately.
- Fallback mode is intentionally simple:
  - Highlight with `vim.fn.matchadd()`.
  - Clear with `vim.fn.matchdelete()`.
  - Navigate with `vim.fn.search()`.
  - Do not add fallback caches, scanned fallback ranges, or other fallback-specific indexing.
- Beacon only renders highlights in exact normal mode (`mode() == 'n'`).
- Entering visual, insert, select, operator-pending, command-line, or any other non-normal mode must clear active highlights and cancel delayed/requested highlight work.
- Returning to normal mode should re-resolve the current target through the usual delayed path instead of keeping stale non-normal state alive.

## Performance Constraints

- LSP requests are the expensive path. Avoid sending them unless the current target really changed.
- Reuse cached data only for LSP entries.
- The per-buffer LSP cache is backed by the bundled third-party module at `lua/beacon/lru.lua`; do not reintroduce bespoke cache-order bookkeeping.
- Buffer `active` state and cache entries are LSP-only records; do not add source tags for fallback state.
- LSP cache validity depends on:
  - buffer `changedtick`
  - internal `server_tick`
- `server_tick` is bumped when LSP state meaningfully changes, including:
  - attach
  - detach
  - progress completion (`LspProgress` with `kind == "end"`) when pending work is finished

## Target Detection

- `word_under_cursor()` uses precompiled `vim.regex`.
- The current line is split at the cursor byte column:
  - last keyword suffix from the left side
  - first keyword prefix from the right side
- Cursor positions on whitespace should return no target.

## Fallback Matching

- Fallback matching must remain case-sensitive.
- The fallback pattern is built from the exact current keyword.
- Let Neovim handle fallback search/match performance internally.

## Attach/Wait Logic

- `lsp_attach_timeout_ms` is still required.
- Before falling back, check `vim.lsp._enabled_configs` against the current filetype.
- If no enabled config covers the filetype, fallback immediately.
- If an enabled config does cover the filetype, wait for attach up to `lsp_attach_timeout_ms`, then fallback.
- Once any LSP client is attached to the buffer, stop waiting.
- If the attached client supports `textDocument/documentHighlight`, use the LSP path.
- If the attached client does not support `textDocument/documentHighlight`, use fallback immediately.

## Navigation

- LSP navigation uses the sorted LSP ranges.
- Merge identical LSP ranges by span before rendering/navigation, and keep the strongest highlight kind for that span.
- `next_reference()` and `prev_reference()` add the current location to Neovim's built-in jumplist before moving.
- `find_range_index()` is binary-search based, assumes the LSP ranges are sorted by start position, and must still tolerate overlapping or nested ranges from servers.
- Fallback navigation must stay based on `vim.fn.search()`, not precomputed fallback ranges.
- `BeaconTarget.key` must include `bufnr` so cross-buffer staleness checks and timer dedup are sound.

## Editing Notes

- Preserve the single-file design unless there is a strong reason to split it.
- Keep comments concise and high-signal.
- Keep the target-resolution decision logic centralized so cursor events, delayed resolution, and manual refreshes do not drift apart.
- `plan_target_resolution()` is a pure decision function: callers supply a pre-computed target; the planner never calls `get_target()` internally.
- Buffer invalidation must clear per-window timers for that buffer before resetting state so pre-edit delayed targets cannot survive a text change.
- Normal-mode `TextChanged` should re-arm current-target resolution with the usual delayed path after invalidation so undo-like edits do not wait for `CursorMoved`; `TextChangedI` remains invalidate-only so insert-mode behavior stays unchanged.
- `render_entry()` only sets extmarks and updates `buf_state.active`; cache mutations (`cache_put`) belong at call sites so rendering and LRU policy stay separate.
- Cursor-driven `delay_ms` gating applies to fallback rendering and cached LSP reuse.
- Cache-miss LSP debounce is dynamic: maintain per-buffer, per-client latency predictions from the last `lsp_latency_samples` observations, seed unknown clients from `lsp_miss_delay_ms`, and subtract the slowest active prediction from `delay_ms`.
- Cache-miss debounce must still respect `lsp_miss_delay_min_ms` so rapid cursor movement cannot collapse uncached LSP requests into an immediate flood.
- Only already-visible `keep_active` and `keep_fallback` states may remain without rearming the timer.
- `setup()` must drain all outstanding timers and pending LSP requests before rebuilding config/state so stale async callbacks never land on new state.
- Non-cursor entry points (`refresh_current_window`, `refresh_current_buffer`) must clear highlights when the cursor has no target or normal-mode gating fails, mirroring the cursor-move cleanup path.
- Keep direct uses of Neovim private LSP APIs wrapped in local compatibility helpers.
- Prefer simple data flow over clever abstractions, especially in fallback mode.
- Whenever behavior, structure, constraints, or maintenance expectations are updated, synchronize this `AGENTS.md` file in the same change.

## Style Rules

- Add LuaLS-style type annotations for all data structures.
- Keep those type annotations synchronized with the actual implementation.
- Prefer LuaLS inference for values returned by Neovim or other library APIs; do not add local wrapper annotations for library-returned clients, regexes, timers, or similar handles unless inference is insufficient.
- Add comments for non-trivial logic and important behavior constraints.
- Comments should stay concise, high-signal, and maintenance-oriented.
- Keep local comments near the subtle flows that are easy to regress: target extraction, attach/wait gating, server-side invalidation, and progress-triggered refresh.

## Verification

- `nvim --headless -u NONE -i NONE '+lua vim.opt.rtp:append(vim.fn.getcwd()); local mod = dofile(vim.fs.joinpath(vim.fn.getcwd(), "init.lua")); mod.setup(); print("setup-ok")' +qall`
- `nvim --headless -u NONE -i NONE '+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), "tests/regression.lua"))' +qall`
- For LuaLS checks, prefer a Neovim-aware `lua-language-server --check` run instead of a bare workspace check.
- Resolve the Neovim runtime dynamically from the current machine, for example by reading `vim.env.VIMRUNTIME` from a headless `nvim` process, and add its `lua` directory to `workspace.library`.
- If available, also add the LuaLS `luv` metadata directory (`meta/3rd/luv/library`) to `workspace.library` so `vim.uv` timer types resolve cleanly.
- Use a temporary LuaLS config that keeps the runtime on `LuaJIT`, marks `vim` as a known global, disables third-party prompts, and points `workspace.library` at those dynamically discovered paths.
- Then run `lua-language-server --check . --checklevel=Hint --configpath <temp-config>` from the plugin root to surface both warnings and hints with Neovim types loaded.
