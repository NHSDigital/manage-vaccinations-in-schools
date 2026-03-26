# Contributing

## Branching strategy

We have three named long-lasting branches in the repo:

- `release` - This represents the version of the code that is deployed to
  production.
- `main` - This represents the version of the code that is either deployed
  to production or assured to be deployed to production.
- `next`- This represents the code that is currently in development and not
  yet ready to be deployed to production.

In most cases, new PRs should be raised against the `next` branch, where once
merged, will go out in the next scheduled release. In the case of an emergency
release it can sometimes be necessary to raise a PR against the `main` branch,
where the `next` branch is then rebased against `main` once merged in.

### Naming

We use simple descriptive names for branches such as `add-patient-model`.
To tie commits to Jira tickets etc. we use Git trailers in the comment, e.g.

```
Jira-Issue: MAV-1234
```

## Code reviews

All pull requests should be reviewed by another developer on the team before
they can be merged in.

Don't be afraid to use "Request changes" when suggesting changes to a pull
request. This helps to make it easier to filter in lists of pull requests
which are still in need of a review, and the person who raised the pull
request can still dismiss the review if they disagree.

## Merging

We use a simple merge rather than a squash merge. Consider doing an
interactive rebase first, to squash any trivial commits that don't add any
value to change history by themselves.
