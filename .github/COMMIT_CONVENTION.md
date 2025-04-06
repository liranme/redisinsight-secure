# Commit Message Guidelines

This project follows [Conventional Commits](https://www.conventionalcommits.org/) for commit messages to enable automatic versioning and CHANGELOG generation.

## Commit Message Format

Each commit message consists of a **header**, a **body** and a **footer**. The header has a special format that includes a **type**, an optional **scope** and a **subject**:

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

Only the **header** is mandatory; the **scope** of the header is optional.

## Types

The commit type must be one of the following:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools and libraries

## Scope

The scope is optional and should be the name of the component affected (as perceived by the person reading the changelog):

- **charts**: Changes to Helm chart files
- **auth**: Authentication related changes
- **ci**: CI/CD pipeline changes
- **deps**: Dependency updates

## Subject

The subject contains a succinct description of the change:

- Use the imperative, present tense: "change" not "changed" nor "changes"
- Don't capitalize the first letter
- No period (.) at the end

## Body

The body should include the motivation for the change and contrast with previous behavior.

## Footer

The footer should contain any information about **Breaking Changes** and is also the place to reference GitHub issues that this commit **Closes**.

Breaking Changes should start with the word `BREAKING CHANGE:` with a space or two newlines. The rest of the commit message is then used for this.

## Examples

```
feat(auth): add support for LDAP authentication

Implements LDAP authentication in addition to local authentication.
Includes LDAP group synchronization for role mapping.

Closes #123
```

```
fix: correct port binding in deployment template

The service was binding to the wrong container port which
caused connection issues.
```

```
docs: update installation instructions

Updated to reflect the latest Helm chart parameters.
```

```
feat!: redesign API authentication flow

BREAKING CHANGE: The authentication flow has been completely
redesigned. Old authentication tokens will not work anymore.
```

```
chore(deps): update Helm dependencies

Updated oauth2-proxy to version 7.2.0
``` 