# Contributing

Thank you for your interest in contributing to the Datadog JUnit Upload GitHub Action!

## Submitting a Pull Request

1. Fork and clone the repository
2. Configure and install the dependencies: `yarn install`
3. Create a new branch: `git checkout -b my-branch-name`
4. Make your changes to the source code in `src/`
5. Update `dist/index.js` using `yarn build`. This bundles the action and all dependencies into a single distributable
6. Make sure the tests pass by running the test workflow (tests run automatically on PRs)
7. Push to your fork and submit a pull request
8. Pat yourself on the back and wait for your pull request to be reviewed and merged

Here are a few things you can do that will increase the likelihood of your pull request being accepted:

- Write clear commit messages explaining the change
- Keep your change as focused as possible. If there are multiple changes you would like to make that are not dependent upon each other, consider submitting them as separate pull requests
- Ensure the bundled `dist/` directory is included in your commits (this is what gets executed when users run the action)

## Development Workflow

### Building

The action uses `@vercel/ncc` to bundle the source code and all dependencies:

```bash
# Install dependencies
yarn install

# Bundle the action
yarn build

# The bundled output will be in dist/
```

**Important:** Always commit the `dist/` directory along with your `src/` changes. The bundled code is what gets executed when users run the action.

### Testing

Tests run automatically on pull requests via `.github/workflows/test.yaml`. The test suite includes:

- **test-upload**: Tests core JUnit upload functionality
- **test-backward-compatibility**: Ensures legacy inputs are handled gracefully
- **test-missing-api-key**: Validates error handling

You can also test locally by:

1. Creating test JUnit XML files in `ci/fixtures/`
2. Using the action in a test repository with `uses: username/junit-upload-github-action@your-branch`

## Architecture

This action uses a bundled architecture for supply chain security:

- **Source**: `src/index.js` - Main action logic
- **Bundled**: `dist/` - Compiled bundle including `@datadog/datadog-ci` and all dependencies
- **Locked**: `yarn.lock` - Dependency versions are locked at build time
- **Security**: No runtime `npx` installations - everything is bundled and verified

When you make changes:
1. Edit `src/index.js`
2. Run `yarn build` to update `dist/`
3. Commit both `src/` and `dist/`

## Resources

- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
- [Using Pull Requests](https://help.github.com/articles/about-pull-requests/)
- [GitHub Help](https://help.github.com)
- [Writing good commit messages](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)

Thanks! ❤️

Datadog Team
