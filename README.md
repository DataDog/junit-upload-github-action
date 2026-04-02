# Datadog JUnitXML Upload Action

This action uploads JUnitXML files to the [Datadog Test Optimization product](https://docs.datadoghq.com/tests/) using a bundled version of [datadog-ci](https://github.com/DataDog/datadog-ci).

**Security:** This action bundles `@datadog/datadog-ci` (v5.11.0) and all its dependencies at build time with locked versions for supply chain security. Dependencies are verified and bundled during the action's release process, eliminating runtime dependency resolution vulnerabilities.

## Usage

```yaml
name: Test Code
on: [ push ]
jobs:
  test:
    steps:
      - uses: actions/checkout@v3
      - run: make tests
      - uses: datadog/junit-upload-github-action@v2
        with:
          api_key: ${{ secrets.DD_API_KEY }}
```

## Inputs

The action has the following options:

| Name             | Description                                                                                                                                                                                                                                            | Required | Default         |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|-----------------|
| `api_key`        | Datadog API key to use to upload the junit files.                                                                                                                                                                                                      | True     |                 |
| `site`           | The Datadog site to upload the files to.                                                                                                                                                                                                               | False    | `datadoghq.com` |
| `files`          | Path to file or folder containing XML files to upload                                                                                                                                                                                                  | False    | `.`             |
| `auto-discovery` | Do a recursive search and automatic XML files discovery in the folders provided in `files` input (current folder if omitted). Search for filenames that match `*junit*.xml`, `*test*.xml`, `*TEST-*.xml`.                                              | False    | `true`          |
| `ignored-paths`  | A comma-separated list of paths that are ignored when junit files auto-discovery is done. Glob patterns are supported.                                                                                                                                 | False    |                 |
| `concurrency`    | Controls the maximum number of concurrent file uploads                                                                                                                                                                                                 | False    | `20`            |
| `tags`           | Optional extra tags to add to the tests formatted as a comma separated list of tags. Example: `foo:bar,data:dog`                                                                                                                                       | False    |                 |
| `service`        | Service name to use with the uploaded test results.                                                                                                                                                                                                    | False    |                 |
| `env`            | Optional environment to add to the tests                                                                                                                                                                                                               | False    |                 |
| `logs`           | When set to "true" enables forwarding content from the XML reports as Logs. The content inside `<system-out>`, `<system-err>`, and `<failure>` is collected as logs. Logs from elements inside a `<testcase>` are automatically connected to the test. | False    |                 |
| `extra-args`     | Extra args to be passed to the datadog-ci junit upload command.                                                                                                                                                                                        | False    |                 |

## Breaking Changes from v2

**Version 3.0.0** introduces important security improvements that include breaking changes:

### Removed Inputs
- **`datadog-ci-version`**: Removed for supply chain security. The `datadog-ci` version is now bundled and locked at action build time. To use a newer version of `datadog-ci`, update to the latest version of this action.
- **`node-version`**: Removed as the action now runs on Node.js 24 internally. This does not affect your workflow's Node.js version.

### Security Improvements
This version addresses [supply chain vulnerability concerns](https://github.com/DataDog/junit-upload-github-action/issues/49) by:
- Bundling `@datadog/datadog-ci` and all dependencies at build time
- Using locked dependency versions via `yarn.lock`
- Eliminating runtime `npx` installations that could pull compromised packages
- Protecting against transitive dependency attacks (like the axios 1.14.1 incident)

### Migration Guide
Most users can upgrade with no changes:
```yaml
# Before (v2.x)
- uses: datadog/junit-upload-github-action@v2
  with:
    api_key: ${{ secrets.DD_API_KEY }}
    datadog-ci-version: "5.10.0"  # This input is now ignored

# After (v3.x) - same code works!
- uses: datadog/junit-upload-github-action@v3
  with:
    api_key: ${{ secrets.DD_API_KEY }}
    # datadog-ci version is bundled in the action
    # Update the action version to get new datadog-ci features
```

**No workflow changes required** - removed inputs (`datadog-ci-version`, `node-version`) are simply ignored if provided.
