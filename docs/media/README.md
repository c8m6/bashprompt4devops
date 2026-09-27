# Terminal captures

Both PNGs were recorded from interactive pseudo-terminal sessions sourcing the
current `bashprompt4devops.sh`, then rendered from the resulting terminal screen.
The commands, Git status, exit status and command runtime come from actual shell
execution; the prompt text was not drawn or substituted by hand.

| Capture | Shell | Scenario |
| --- | --- | --- |
| `bash-git-kubernetes.png` | Bash 5.2.26 | A clean `main` branch followed by one changed tracked entry, one untracked entry, one commit ahead/behind its upstream, a local Kubernetes context and `sleep 1`. |
| `zsh-conflict.png` | zsh 5.9 | A real merge conflict in `app.conf`, the merge's exit status `1`, and the unmerged entry in `git status --short`. |

The repositories and remote are temporary local fixtures. The user `dev`, host
`workstation` and Kubernetes context `staging-eu` are demo values. Automatic
fetching is disabled during capture, and the fixture's remote refs are refreshed
explicitly. No personal repository or cluster credentials are used.

Rendering uses an 88-column terminal, a dark ANSI palette and the DejaVu Sans Mono Nerd
Font Mono. The exit-status marker is a plain `!` and needs no special font.
Colors can look different in your own terminal. The clock shows the
capture's local time.
