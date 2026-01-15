# Datadog JUnitXML Upload Action

This action downloads the [datadog-ci](https://github.com/DataDog/datadog-ci) and uses it to upload JUnitXML files
to the [Test Optimization product](https://docs.datadoghq.com/tests/).

This action sets up node and requires node `>=14`. You can configure a specific version of node to use.
Note that if you have set up another version already it will override it.

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
| `node-version`       | The node version to use to install the datadog-ci. It must be `>=14`                                                                                                                                                                                   | False    | `20`            |
| `tags`               | Optional extra tags to add to the tests formatted as a comma separated list of tags. Example: `foo:bar,data:dog`                                                                                                                                       | False    |                 |
| `service`            | Service name to use with the uploaded test results.                                                                                                                                                                                                    | False    |                 |
| `env`                | Optional environment to add to the tests                                                                                                                                                                                                               | False    |                 |
| `logs`               | When set to "true" enables forwarding content from the XML reports as Logs. The content inside `<system-out>`, `<system-err>`, and `<failure>` is collected as logs. Logs from elements inside a `<testcase>` are automatically connected to the test. | False    |                 |
| `datadog-ci-version` | Override the @datadog/datadog-ci version. Leave empty to use the bundled version.                                                                                                                                                                      | False    |                 |
| `extra-args`         | Extra args to be passed to the datadog-ci junit upload command.                                                                                                                                                                                        | False    |                 |
