# Issue tracker: GitHub

Issues and specs for this repository live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`.
- **Read an issue**: `gh issue view <number> --json number,title,body,labels,comments`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments`.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `gh issue edit <number> --remove-label "..."`.
- **Close**: `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`. Until a GitHub remote is configured, pass `--repo <owner>/<repo>` explicitly to `gh` commands.

## Task decomposition and execution

- **Publish a task**: Create a GitHub issue with its changeset and acceptance criteria.
- **Dependencies**: Use GitHub's native issue dependencies where available; otherwise record `Blocked by: #<number>` in the issue body. An issue is unblocked when all referenced blockers are closed.
- **Frontier**: The active frontier is the earliest ordered open issue whose blockers are all closed.
- **Claim**: Assign the issue to the active contributor.
- **Resolve**: Verify all acceptance criteria, post a resolution comment, and close the issue.
