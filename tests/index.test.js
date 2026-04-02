const { parseInputs } = require('../src/index');

describe('parseInputs', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    // Clear all INPUT_ vars
    Object.keys(process.env).forEach(key => {
      if (key.startsWith('INPUT_')) {
        delete process.env[key];
      }
    });
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  test('parses basic inputs', () => {
    process.env.INPUT_API_KEY = 'test-key';

    const inputs = parseInputs();

    expect(inputs.apiKey).toBe('test-key');
    expect(inputs.site).toBe('datadoghq.com'); // default
    expect(inputs.files).toBe('.'); // default
    expect(inputs.concurrency).toBe('20'); // default
    expect(inputs.autoDiscovery).toBe('true'); // default
  });

  test('uses custom values when provided', () => {
    process.env.INPUT_API_KEY = 'custom-key';
    process.env.INPUT_SITE = 'datadoghq.eu';
    process.env.INPUT_FILES = 'custom-files/**';
    process.env.INPUT_CONCURRENCY = '5';

    const inputs = parseInputs();

    expect(inputs.apiKey).toBe('custom-key');
    expect(inputs.site).toBe('datadoghq.eu');
    expect(inputs.files).toBe('custom-files/**');
    expect(inputs.concurrency).toBe('5');
  });

  test('handles kebab-case input names', () => {
    process.env.INPUT_AUTO_DISCOVERY = 'false';
    process.env.INPUT_IGNORED_PATHS = 'node_modules/**';
    process.env.INPUT_EXTRA_ARGS = '--verbose';

    const inputs = parseInputs();

    expect(inputs.autoDiscovery).toBe('false');
    expect(inputs.ignoredPaths).toBe('node_modules/**');
    expect(inputs.extraArgs).toBe('--verbose');
  });

  test('handles optional inputs', () => {
    process.env.INPUT_API_KEY = 'test-key';
    process.env.INPUT_SERVICE = 'my-service';
    process.env.INPUT_ENV = 'staging';
    process.env.INPUT_TAGS = 'team:backend';
    process.env.INPUT_LOGS = 'true';

    const inputs = parseInputs();

    expect(inputs.service).toBe('my-service');
    expect(inputs.env).toBe('staging');
    expect(inputs.tags).toBe('team:backend');
    expect(inputs.logs).toBe('true');
  });

  test('returns empty strings for missing optional inputs', () => {
    process.env.INPUT_API_KEY = 'test-key';

    const inputs = parseInputs();

    expect(inputs.service).toBe('');
    expect(inputs.env).toBe('');
    expect(inputs.tags).toBe('');
    expect(inputs.logs).toBe('');
  });
});
