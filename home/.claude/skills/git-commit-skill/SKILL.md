---
name: commit
description: Generate Git commit messages following project conventions. Use when the user wants to commit changes or asks for a commit message. Analyzes staged/unstaged changes and produces properly formatted commit messages with tags, capitalized summaries, and prose bodies.
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion
argument-hint: [description of changes]
---

# Git Commit Message Skill

Generate and create Git commit messages following the project's strict formatting rules.
The message is always shown to the user for approval before any commit is made.

## Commit Message Format

```
[TAG] Short summary opening with a capital

Detailed description of the change, written in prose and wrapped at
72 characters.
```

## Tags

- `[BUG FIX]` = A bug fix
- `[FEATURE]` = New feature code
- `[REFACTOR]` = A code refactor
- `[TEST CODE]` = Added test code
- `[TIDY]` = A tidy up action such as reformatting or spelling fixes

## Special Case

If this is the very first commit of a project (no prior commits exist), the entire commit message must be exactly:

```
Initial commit
```

No tag, no body.

## Summary Line Rules

- Must begin with a tag in square brackets (except "Initial commit")
- Must open with a capital letter; the words after it are free, so a lower case
  tool or file name (`ps`, `pgrep`, `lproj`) stays as it is written
- Must be short and concise
- Must NOT end with a period

## Body Rules

- One blank line between the summary line and the body
- Body must be written in prose (complete sentences, paragraph form)
- Body must NOT use bullet points or lists
- Wrap all lines at 72 characters
- No mention of claude session or AI assistant should be included

## Workflow

1. Run `git status` to see what has changed
2. Run `git diff --cached` to see staged changes; if nothing is staged, run `git diff` to see unstaged changes
3. Check `git log --oneline -1` to determine if this is the first commit (if it errors, it is the first commit)
4. Analyze the changes to determine the appropriate tag and write a clear summary and description
5. Check for a README file at the repo root (`README.markdown` (preferred), `README.md`, `README`, `README.rst`, `README.txt`). If one exists, read it and determine whether the changes make any part of it stale or incomplete (features added/removed, usage changed, install steps, options, file layout, etc.). If so, update the README in the same commit. If the README is unaffected, proceed without changes.
6. Stage files if needed (prefer staging specific files over `git add -A`)
7. Write the message to `.git/COMMIT_EDITMSG` using a quoted HEREDOC:
   ```
   cat > "$(git rev-parse --git-dir)/COMMIT_EDITMSG" <<'EOF'
   [TAG] Short summary opening with a capital

   Detailed description of the change.
   EOF
   ```
8. Run the **Approval Step** below. Do not commit until it returns approved text.
9. Commit from the file — never re-type the approved text into `-m`:
   ```
   git commit -F "$(git rev-parse --git-dir)/COMMIT_EDITMSG"
   ```

## Approval Step

Print the full proposed message in the response, then call `AskUserQuestion`
with one question, header `Commit msg`, and these options:

- **Approve** — commit with the message as written
- **Edit** — open the message in the editor and commit what comes back
- **Cancel** — make no commit

### On Approve

Proceed to the commit. Change nothing about the text.

### On Edit

1. Resolve the editor, in this order, taking the first non-empty value:
   `git config core.editor`, then `$VISUAL`, then `$EDITOR`.
   **Ignore `$GIT_EDITOR`** — Claude Code sets it to `true` in the environment,
   so it silently makes no edit. If none of the three is set, tell the user and
   fall back to the manual path below.
2. Launch the editor on `.git/COMMIT_EDITMSG` from Bash with a 600000 ms
   timeout, and only with an option that makes it block until the file is
   closed (`--wait`, `-w`, `--block`). A GUI editor such as `bbedit --wait`
   blocks correctly this way.
3. A terminal editor (`vim`, `nano`, `emacs -nw`, `hx`) has no TTY under the
   Bash tool and will fail or return instantly. When the resolved editor is one
   of those — or the launch errors, or returns with the file unchanged — do not
   retry: ask the user to run it themselves by typing
   `! <editor> .git/COMMIT_EDITMSG` at the prompt, then wait for them to say
   they are done.
4. Read the file back. Strip lines beginning with `#` and any trailing blank
   lines.
5. If what remains is empty or whitespace only, the commit is aborted — same as
   Git's own behavior. Say so and stop.
6. Use the edited text verbatim. Do not reformat it, re-wrap it, re-tag it, or
   correct it against the rules above — the user's edit is final. If it violates
   a formatting rule, commit it anyway and note the discrepancy in one line
   after the commit.
7. Commit with `git commit -F` as in step 9.

### On Cancel

Make no commit. Leave the index exactly as it is — do not unstage anything that
was staged in step 6. Say what remains staged.

## Argument Handling

- If `$ARGUMENTS` is provided, treat it as a description of the changes to help craft the commit message
- If no arguments, analyze the diff to determine the appropriate message
- Always review the actual changes before committing — do not rely solely on the user's description
