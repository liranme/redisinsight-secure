# Commit Message Guidelines

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification to have human and machine-readable commit messages. This leads to more structured commit history and automatic version management based on commit types.

## Commit Message Format

Each commit message consists of a **header**, a **body**, and a **footer**:

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

The **header** is mandatory, while the **body** and **footer** are optional.

### Type

Must be one of the following:

* **feat**: A new feature (triggers a MINOR version bump)
* **fix**: A bug fix (triggers a PATCH version bump)
* **docs**: Documentation only changes
* **style**: Changes that do not affect the meaning of the code (e.g., formatting)
* **refactor**: A code change that neither fixes a bug nor adds a feature
* **perf**: A code change that improves performance
* **test**: Adding missing or correcting existing tests
* **chore**: Changes to the build process or auxiliary tools and libraries
* **ci**: Changes to CI configuration files and scripts
* **revert**: Reverts a previous commit

### Scope

The scope provides additional contextual information:

* **chart**: Changes related to the Helm chart
* **deps**: Changes to dependencies
* **ui**: User interface related changes
* **auth**: Authentication related changes

The scope is optional and can be omitted.

### Subject

The subject contains a succinct description of the change:

* Use the imperative, present tense: "change" not "changed" nor "changes"
* Don't capitalize the first letter
* No period (.) at the end

### Body

The body should include the motivation for the change and contrast this with previous behavior.

### Footer

The footer should contain information about Breaking Changes and reference GitHub issues that this commit closes.

Breaking changes should start with the phrase `BREAKING CHANGE:` with a space or two newlines.

## Examples

```
feat(chart): add support for oauth2 authentication

Add OAuth2 proxy as an optional component in the Helm chart.
This allows users to integrate with external authentication providers.

Closes #123
```

```
fix: correct port binding in deployment template

The container port was incorrectly mapped which caused connection issues.
```

```
BREAKING CHANGE: drop support for kubernetes 1.16

Due to dependency requirements, we can no longer support Kubernetes versions below 1.18.
```

## Automatic Versioning

This repository uses these conventional commits to automatically:

1. Determine the next semantic version number
2. Generate changelogs
3. Publish new releases

* `fix:` commits trigger PATCH releases (1.0.0 -> 1.0.1)
* `feat:` commits trigger MINOR releases (1.0.0 -> 1.1.0)
* `feat(scope): .... BREAKING CHANGE:` trigger MAJOR releases (1.0.0 -> 2.0.0) 