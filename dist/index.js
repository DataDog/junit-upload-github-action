require('./sourcemap-register.js');/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ 351:
/***/ ((module, __unused_webpack_exports, __nccwpck_require__) => {

const { spawn } = __nccwpck_require__(81);

/**
 * Get input value from environment variable
 * GitHub Actions converts inputs to env vars with INPUT_ prefix
 */
function getInput(name) {
  const envName = `INPUT_${name.replace(/-/g, '_').toUpperCase()}`;
  return process.env[envName] || '';
}

/**
 * Build command arguments for datadog-ci junit upload
 * @param {Object} inputs - Parsed input values
 * @returns {string[]} Command arguments array
 */
function buildArgs(inputs) {
  const args = ['junit', 'upload'];

  args.push('--max-concurrency', inputs.concurrency);

  if (inputs.logs === 'true') {
    args.push('--logs');
  }

  if (inputs.autoDiscovery === 'true') {
    args.push('--auto-discovery');
  }

  if (inputs.ignoredPaths) {
    args.push('--ignored-paths', inputs.ignoredPaths);
  }

  if (inputs.service) {
    args.push('--service', inputs.service);
  }

  // Add extra args if provided
  if (inputs.extraArgs) {
    const parsed = inputs.extraArgs.split(' ').filter(arg => arg.trim());
    args.push(...parsed);
  }

  // Add files path
  args.push(inputs.files);

  return args;
}

/**
 * Build environment variables for datadog-ci
 * @param {Object} inputs - Parsed input values
 * @returns {Object} Environment variables
 */
function buildEnv(inputs) {
  const env = { ...process.env };

  env.DD_API_KEY = inputs.apiKey;
  env.DD_SITE = inputs.site;

  if (inputs.env) {
    env.DD_ENV = inputs.env;
  }

  if (inputs.tags) {
    env.DD_TAGS = inputs.tags;
  }

  return env;
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

    // Build command arguments and environment
    const args = buildArgs(inputs);
    const env = buildEnv(inputs);

    // Execute datadog-ci CLI by requiring and running it
    // We'll use the CLI entry point from the bundled package
    const datadogCiPath = __nccwpck_require__.ab + "cli.js";

    // Execute as a child process with node
    const child = spawn(process.execPath, [__nccwpck_require__.ab + "cli.js", ...args], {
      stdio: 'inherit',
      env
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

// Export for testing
module.exports = { buildArgs, buildEnv, parseInputs, run };

// Run the action if executed directly
if (require.main === require.cache[eval('__filename')]) {
  run();
}


/***/ }),

/***/ 81:
/***/ ((module) => {

"use strict";
module.exports = require("child_process");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __nccwpck_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		var threw = true;
/******/ 		try {
/******/ 			__webpack_modules__[moduleId](module, module.exports, __nccwpck_require__);
/******/ 			threw = false;
/******/ 		} finally {
/******/ 			if(threw) delete __webpack_module_cache__[moduleId];
/******/ 		}
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat */
/******/ 	
/******/ 	if (typeof __nccwpck_require__ !== 'undefined') __nccwpck_require__.ab = __dirname + "/";
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module is referenced by other modules so it can't be inlined
/******/ 	var __webpack_exports__ = __nccwpck_require__(351);
/******/ 	module.exports = __webpack_exports__;
/******/ 	
/******/ })()
;
//# sourceMappingURL=index.js.map