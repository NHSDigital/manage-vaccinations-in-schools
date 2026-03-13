# Releasing

The `next` branch is used to collect and test changes before a release. Only
changes scheduled for the next release should be in `next`, and commits may be
reverted or added to reflect scope changes.

Once a release has gone through the assurance stops and ready to release, `next`
is merged into `main` using a PR, and then `main` is deployed out to production.

The `release` branch is a reference to what is in production at any point in
time and updated at the time the release is performed. It usually tracks `main`
but can also point to hotfix branches as necessary.

Releasing follows these steps, performed once approval for release has been
given:

1. Create a PR to merge `next` into `main`. GitHub will have a warning that
   `next` isn't up-to-date with `main`, but that is likely caused by the
   existance of a merge commit from the last deploy. You can double check
   locally by updating `main` and `next`, and using git (
   `git rev-list --oneline main ^next`) or jj (`jj log -r '::main ~ ::next'`),
   or by [comparing the branches on
   GitHub](https://github.com/nhsuk/manage-vaccinations-in-schools/compare/next...main).
2. Create a draft release by running the [`Draft new release`
   workflow](https://github.com/nhsuk/manage-vaccinations-in-schools/actions/workflows/draft-new-release.yml).
   This creates a draft release in GitHub with initial release notes.
3. Update the release notes with information about the changes. This is
   generated from the Jira tickets by a team member.
4. Publish the release in GitHub. This will create the tag.
5. Check the notes for pre and post-release tasks and ensure these are performed
   before and after releasing to the environments below.
6. Deploy the release to the `preview` and `training` envs, first checking that
   they haven't had a specific branch deployed to them (check [recent
   deploys](https://github.com/nhsuk/manage-vaccinations-in-schools/actions/workflows/deploy.yml)).
   This can be used as a test that the tag deploys as expected.
7. If there are migrations that need testing (e.g. a db or data migrations),
   deploy this release to `data-replication` and test the performance of the
   migration(s) there.
8. Perform pre-release tasks.
9. Run the [Deploy
   workflow](https://github.com/NHSDigital/manage-vaccinations-in-schools/actions/workflows/deploy.yml)
   to deploy to production.
10. Run the [Deploy application
    workflow](https://github.com/NHSDigital/manage-vaccinations-in-schools-reporting/actions/workflows/deploy-application.yml)
    for the reporting app. You may need to ask other team members for the
    correct tag.
11. Smoke test: login to the production service to ensure it looks normal.
12. Perform post-release tasks.
13. Fast-forward or reset `release` to the release tag.
14. Update the service management channel on NHSE Slack.
15. Update the topic in the Mavis tech channel to reflect the new version.

Additional notes below.

## Running the Deploy workflow

Use the `deploy.yml` workflow to run the deployments. For the production
deployment, it's important to start the workflow from the `main` branch and
specify the tag to deploy as input. This is because only workflows from the
`main` branch can authenticate with the production AWS account.

## Upading the release branch

We update the `release` branch after we've deployed `main` to production. If
there have been no hot-fixes since the last release then this is a simple
fast-forward merge that has to be done on your localhost (see below for how to
manage non-fast-forwardable situations):

```shell
git checkout release
git pull origin release

# Check that release can be fast-forwarded to the release candidate
git merge-base --is-ancestor release v1.0.0-rc1 && echo "safe to ff-merge"
# If release has diverged from main and cannot be fast-forwarded to the release
# candidate, see the instructions below

git merge --ff-only v1.0.0-rc1
git push --tags origin release
```

### When `release` and `main` have diverged

There are cases when `release` won't be fast-forwardable to the release
candidate on `main`. This will happen when a fix has been applied to the
`release` branch that circumvented the normal release cycle (AKA hot-fix, see
below).

In these cases the `release` branch will need to be reset to the latest release
candidate.

```sh
git checkout release
git pull origin release
git reset --hard v1.0.0-rc1
git push --tags origin release
```

And then you can follow the instructions above about creating the release tag
and deploying.

## Hot-fixes

Hot-fixes are emergency fixes made to the current release that bypass changes
that are in `main`. These fixes should still go through the pull-request
process, but to a version-specific branch, e.g. `v1.0.1-hotfixes`. Once these
are merged in, the commits will need to be applied to `main`, e.g. via
cherry-picking, and `release` should be fast-forwarded/reset to the latest code
released.

```mermaid
gitGraph
    branch release
    commit tag: "v0.9.9"
    checkout main
    commit tag: "v1.0.0-rc1, v1.0.0"
    checkout release
    merge main tag: "v1.0.0"
    checkout main
    commit id: "v1.1.0-feature-1"
    commit id: "v1.1.0-feature-2"
    checkout release
    branch v1.0.1-hotfixes
    commit id: "v1.0.1-hotfix-1"
    checkout main
    cherry-pick id: "v1.0.1-hotfix-1"
    commit id: "v1.1.0-feature-3"
    checkout release
    merge v1.0.1-hotfixes tag: "v1.0.1"
    checkout main
```

At this point the histories of the `release` and `main` branches will have
diverged and it will not be possible to fast-forward the `release` branch when
releasing. It will have to be reset to the latest release candidate as
previously described.

## Rollback

A release can be rolled back by deploying the previous release tag using the
regular GitHub workflow. This can be done on a per-service level or for all
services. If the issue is spotted early and the CodeDeploy deployment is still
in progress, the new deployment can still be aborted. To do this, go to the
CodeDeploy console, select the deployment group, and click "Stop deployment".
