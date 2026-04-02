const { PluginCommand } = require('@datadog/datadog-ci-plugin-junit/commands/upload');

/**
 * Get input value from environment variable
 * GitHub Actions converts inputs to env vars with INPUT_ prefix
 */
function getInput(name) {
  const envName = `INPUT_${name.replace(/-/g, '_').toUpperCase()}`;
  return process.env[envName] || '';
}

/**
 * Parse inputs from environment variables
 * @returns {Object} Parsed inputs
 */
function parseInputs() {
  return {
    apiKey: getInput('api_key'),
    site: getInput('site') || 'datadoghq.com',
    files: getInput('files') || '.',
    autoDiscovery: getInput('auto-discovery') || 'true',
    ignoredPaths: getInput('ignored-paths'),
    concurrency: getInput('concurrency') || '20',
    tags: getInput('tags'),
    service: getInput('service'),
    env: getInput('env'),
    logs: getInput('logs'),
    extraArgs: getInput('extra-args')
  };
}

/**
 * Main action function
 */
async function run() {
  try {
    const inputs = parseInputs();

    // Validate required inputs
    if (!inputs.apiKey) {
      throw new Error('api_key is required');
    }

    // Set environment variables for datadog-ci
    process.env.DD_API_KEY = inputs.apiKey;
    process.env.DD_SITE = inputs.site;
    if (inputs.env) process.env.DD_ENV = inputs.env;
    if (inputs.tags) process.env.DD_TAGS = inputs.tags;

    // Execute the junit upload command programmatically
    // Set up CLI context with stdio streams
    const context = {
      stdin: process.stdin,
      stdout: process.stdout,
      stderr: process.stderr,
      colorDepth: process.stdout.isTTY ? 8 : 1
    };

    const command = new PluginCommand();
    command.context = context;
    command.cli = {
      binaryName: 'datadog-ci',
      binaryVersion: '5.11.0'
    };

    // Set command properties to match Clipanion Option types
    // basePaths: string[] (from Option.Rest)
    command.basePaths = [inputs.files];

    // maxConcurrency: string (from Option.String with validator)
    command.maxConcurrency = inputs.concurrency;

    // logs: string 'true'/'false' (from Option.String with tolerateBoolean)
    command.logs = inputs.logs || 'false';

    // automaticReportsDiscovery: string 'true'/'false' (from Option.String with tolerateBoolean)
    command.automaticReportsDiscovery = inputs.autoDiscovery || 'true';

    // skipGitMetadataUpload: string 'true'/'false' (from Option.String with tolerateBoolean)
    command.skipGitMetadataUpload = 'false';

    // verbose: boolean (from Option.Boolean)
    command.verbose = false;

    // dryRun: boolean (from Option.Boolean)
    command.dryRun = false;

    // Optional string fields (must be explicitly set to avoid Option objects)
    command.ignoredPaths = inputs.ignoredPaths || undefined;
    command.service = inputs.service || undefined;
    command.env = inputs.env || undefined;
    command.gitRepositoryURL = undefined;

    // tags: string[] (from Option.Array)
    if (inputs.tags) {
      command.tags = inputs.tags.split(',').map(tag => tag.trim());
    }

    // Explicitly set optional array fields to undefined to avoid Option object issues
    command.rawXPathTags = undefined;
    command.measures = undefined;
    command.reportTags = undefined;
    command.reportMeasures = undefined;

    const exitCode = await command.execute();

    if (exitCode !== 0 && exitCode !== undefined) {
      throw new Error(`junit upload failed with code ${exitCode}`);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Export for testing
module.exports = { parseInputs, run };

// Run the action if executed directly
if (require.main === module) {
  run();
}
