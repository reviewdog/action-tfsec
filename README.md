# GitHub Action: Run tfsec with reviewdog

This action runs [tfsec](https://github.com/liamg/tfsec) with
[reviewdog](https://github.com/reviewdog/reviewdog) on pull requests
to enforce best practices.

## Examples

### With `github-pr-check`

By default, with `reporter: github-pr-check` an annotation is added to
the line:

![Example comment made by the action, with github-pr-check](./example-github-pr-check.png)

### With `github-pr-review`

With `reporter: github-pr-review` a comment is added to
the Pull Request Conversation:

![Example comment made by the action, with github-pr-review](./example-github-pr-review.png)

## Inputs

### `github_token`

**Required**. Must be in form of `github_token: ${{ secrets.github_token }}`.

### `level`

Optional. Report level for reviewdog [`info`,`warning`,`error`].
It's same as `-level` flag of reviewdog.
The default is `error`.

### `reporter`

Optional. Reporter of reviewdog command [`github-pr-check`,`github-pr-review`].
The default is `github-pr-check`.

### `flags`

Optional. List of arguments to send to tfsec.
For the output to be parsable by reviewdog [`--format=checkstyle` is enforced](./entrypoint.sh).
The default is ``.

## Example usage

```yml
name: tfsec
on: [pull_request]
jobs:
  tfsec:
    name: runner / tfsec
    runs-on: ubuntu-latest

    steps:
      - name: Clone repo
        uses: actions/checkout@master

      - name: tfsec
        uses: reviewdog/action-tfsec@master
        with:
          github_token: ${{ secrets.github_token }}
          reporter: github-pr-review # Change reporter
          flags: "" # Optional
```
