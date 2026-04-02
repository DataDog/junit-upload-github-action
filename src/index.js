const { spawn } = require('child_process');
const path = require('path');

/**
 * Get input value from environment variable
 * GitHub Actions converts inputs to env vars with INPUT_ prefix
 */
function getInput(name) {
  const envName = `INPUT_${name.replace(/-/g, '_').toUpperCase()}`;
  return process.env[envName] || '';
}

/**
 * Main action function
 */
async function run() {
  try {
    // Get inputs
    const apiKey = getInput('api_key');
    const site = getInput('site') || 'datadoghq.com';
    const files = getInput('files') || '.';
    const autoDiscovery = getInput('auto-discovery') || 'true';
    const ignoredPaths = getInput('ignored-paths');
    const concurrency = getInput('concurrency') || '20';
    const tags = getInput('tags');
    const service = getInput('service');
    const env = getInput('env');
    const logs = getInput('logs');
    const extraArgs = getInput('extra-args');

    // Validate required inputs
    if (!apiKey) {
      throw new Error('api-key is required');
    }

    // Set environment variables for datadog-ci
    process.env.DD_API_KEY = apiKey;
    process.env.DD_SITE = site;
    if (env) process.env.DD_ENV = env;
    if (tags) process.env.DD_TAGS = tags;

    // Build command arguments
    const args = ['junit', 'upload'];

    args.push('--max-concurrency', concurrency);

    if (logs === 'true') {
      args.push('--logs');
    }

    if (autoDiscovery === 'true') {
      args.push('--auto-discovery');
    }

    if (ignoredPaths) {
      args.push('--ignored-paths', ignoredPaths);
    }

    if (service) {
      args.push('--service', service);
    }

    // Add extra args if provided
    if (extraArgs) {
      args.push(...extraArgs.split(' ').filter(arg => arg));
    }

    // Add files path
    args.push(files);

    // Execute datadog-ci CLI by requiring and running it
    // We'll use the CLI entry point from the bundled package
    const datadogCiPath = require.resolve('@datadog/datadog-ci/dist/cli.js');

    // Execute as a child process with node
    const child = spawn(process.execPath, [datadogCiPath, ...args], {
      stdio: 'inherit',
      env: process.env
    });

    // Wait for the process to complete
    const exitCode = await new Promise((resolve) => {
      child.on('close', resolve);
    });

    if (exitCode !== 0) {
      throw new Error(`datadog-ci exited with code ${exitCode}`);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Run the action
run();
