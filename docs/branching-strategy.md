# Branching Strategy

This repository uses `internal-preview` as the integration branch for internal development on top of upstream Plane `preview`.

## Remotes

- `origin`: `https://github.com/aaaa-gen/plane` (your fork)
- `upstream`: `https://github.com/makeplane/plane` (source project)

Set up once:

```sh
git remote add upstream https://github.com/makeplane/plane
git fetch --all
```

## Branch model

- `internal-preview`: long-lived integration branch.
- `feat/<name>`: short-lived feature branches created from `internal-preview`.
- `release/<version-or-date>`: optional stabilization branch for deploy prep.
- `hotfix/<name>`: urgent fixes from current release branch or deploy commit.

## Daily workflow

1. Sync integration branch with upstream:

```sh
git checkout internal-preview
git fetch upstream
git rebase upstream/preview
git push --force-with-lease origin internal-preview
```

2. Start feature work:

```sh
git checkout -b feat/<short-name>
```

3. Commit and publish:

```sh
git push -u origin feat/<short-name>
```

4. Open PR from `feat/<short-name>` to `internal-preview`.

## Release workflow

1. Cut a release branch:

```sh
git checkout -b release/<version-or-date> internal-preview
git push -u origin release/<version-or-date>
```

2. Deploy from an explicit commit or tag.
3. Merge release/hotfix changes back into `internal-preview`.

## Sync policy

- Rebase `internal-preview` on `upstream/preview` regularly (for example weekly).
- Resolve upstream conflicts in `internal-preview`, not repeatedly across feature branches.
- Keep `internal-preview` protected with required PR review and CI.

## Deployment safety

- Tag deployable commits, for example `vX.Y.Z-internal.N`.
- Prefer immutable image tags (commit SHA) for deploys and rollback.
- Keep infrastructure/config changes separate from app feature changes when possible.
