# Datadog JUnitXML Upload Actions

This action downloads the [datadog-ci](https://github.com/DataDog/datadog-ci) and uses it to upload JUnitXML files
to the [CI Visibility product](https://docs.datadoghq.com/continuous_integration/).

This action sets up node and requires node `>=14`. You can configure a specific version of node to use.
Note that if you have setup another version already it will override it.

## Usage

```yaml
name: Test Code
on: [push]
jobs:
  test:
    steps:
      - uses: actions/checkout@v3
      - run: make tests
      - uses: datadog/junit-upload-github-action@v1
        with:
            api_key: ${{ secrets.DD_API_KEY }}
            service: my-app
            files: ./reports/
```

## Inputs

The action has the following options:

| Name | Description | Required | Default |
| ---- | ----------- | -------- | ------- |
| `api_key` | Datadog API key to use to upload the junit files. | True | |
| `service` | Service name to use with the uploaded test results. | True | |
| `site` | The Datadog site to upload the files to. | True | `datadoghq.com` |
| `files` | Path to file or folder containing XML files to upload | True | `.` |
| `concurrency` | Controls the maximum number of concurrent file uploads | True | `20` |
| `node-version` | The node version to use to install the datadog-ci. It must be `>=14` | True | `20` |
| `tags` | Optional extra tags to add to the tests formmatted as a comma separated list of tags. | False | |
| `env` | Optional environment to add to the tests | False | |
| `logs` | When set to "true" enables forwarding content from the XML reports as Logs. The content inside `<system-out>`, `<system-err>`, and `<failure>` is collected as logs. Logs from elements inside a `<testcase>` are automatically connected to the test. | False | |
| `datadog-ci-version` | Optionally pin the @datadog/datadog-ci version. | False | `latest` |
| `extra-args` | Extra args to be passed to the datadog-ci junit upload command.| False | |
