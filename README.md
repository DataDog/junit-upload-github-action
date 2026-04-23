# Datadog JUnitXML Upload Action

This action installs a pre-built [datadog-ci](https://github.com/DataDog/datadog-ci) binary and uses it to upload JUnitXML files
to the [Test Optimization product](https://docs.datadoghq.com/tests/).

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

| Name                 | Description                                                                                                                                                                                                                                            | Required | Default         |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|-----------------|
| `api_key`            | Datadog API key to use to upload the junit files.                                                                                                                                                                                                      | True     |                 |
| `site`               | The Datadog site to upload the files to.                                                                                                                                                                                                               | False    | `datadoghq.com` |
| `files`              | Path to file or folder containing XML files to upload                                                                                                                                                                                                  | False    | `.`             |
| `auto-discovery`     | Do a recursive search and automatic XML files discovery in the folders provided in `files` input (current folder if omitted). Search for filenames that match `*junit*.xml`, `*test*.xml`, `*TEST-*.xml`.                                              | False    | `true`          |
| `ignored-paths`      | A comma-separated list of paths that are ignored when junit files auto-discovery is done. Glob patterns are supported.                                                                                                                                 | False    |                 |
| `concurrency`        | Controls the maximum number of concurrent file uploads                                                                                                                                                                                                 | False    | `20`            |
| `tags`               | Optional extra tags to add to the tests formatted as a comma separated list of tags. Example: `foo:bar,data:dog`                                                                                                                                       | False    |                 |
| `service`            | Service name to use with the uploaded test results.                                                                                                                                                                                                    | False    |                 |
| `env`                | Optional environment to add to the tests                                                                                                                                                                                                               | False    |                 |
| `logs`               | When set to "true" enables forwarding content from the XML reports as Logs. The content inside `<system-out>`, `<system-err>`, and `<failure>` is collected as logs. Logs from elements inside a `<testcase>` are automatically connected to the test. | False    |                 |
| `datadog-ci-version` | Version of datadog-ci to install. Use a major version like `v5` to get the latest release within that major version, or a specific tag like `v5.6.0` to pin. Legacy npm semver syntax (`^`, `~`, `>=`, `latest`) is still supported but deprecated. | False    | `v5`            |
| `github-token`       | GitHub token to use for authenticated datadog-ci release resolution. Defaults to the workflow `github.token` when omitted.                                                                                                                           | False    | `github.token`  |
| `extra-args`         | Extra args to be passed to the datadog-ci junit upload command.                                                                                                                                                                                        | False    |                 |

This action passes the workflow `github.token` to the install step by default. That is primarily useful when `datadog-ci-version` uses a floating release selector such as `v5`, because GitHub release resolution can then be authenticated. To avoid depending on latest-within-major resolution, pin an exact `datadog-ci` version such as `v5.6.0` or `5.6.0`.
