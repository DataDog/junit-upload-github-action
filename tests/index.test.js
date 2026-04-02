const { buildArgs, buildEnv, parseInputs } = require('../src/index');

describe('buildArgs', () => {
  test('builds basic args with minimal inputs', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      files: '.'
    });

    expect(args).toEqual([
      'junit', 'upload',
      '--max-concurrency', '20',
      '--auto-discovery',
      '.'
    ]);
  });

  test('adds logs flag when enabled', () => {
    const args = buildArgs({
      concurrency: '20',
      logs: 'true',
      autoDiscovery: 'true',
      files: '.'
    });

    expect(args).toContain('--logs');
  });

  test('does not add logs flag when false or missing', () => {
    const args = buildArgs({
      concurrency: '20',
      logs: 'false',
      autoDiscovery: 'true',
      files: '.'
    });

    expect(args).not.toContain('--logs');
  });

  test('disables auto-discovery when set to false', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'false',
      files: 'specific-file.xml'
    });

    expect(args).not.toContain('--auto-discovery');
    expect(args).toContain('specific-file.xml');
  });

  test('adds ignored-paths when provided', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      ignoredPaths: 'node_modules/**,tmp/**',
      files: '.'
    });

    expect(args).toContain('--ignored-paths');
    expect(args).toContain('node_modules/**,tmp/**');
  });

  test('does not add ignored-paths when empty', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      files: '.'
    });

    expect(args).not.toContain('--ignored-paths');
  });

  test('adds service when provided', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      service: 'my-service',
      files: '.'
    });

    expect(args).toContain('--service');
    expect(args).toContain('my-service');
  });

  test('parses extra args correctly', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      extraArgs: '--verbose --dry-run',
      files: '.'
    });

    expect(args).toContain('--verbose');
    expect(args).toContain('--dry-run');
  });

  test('handles empty extra args', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      extraArgs: '',
      files: '.'
    });

    // Should not contain empty strings
    expect(args.filter(arg => arg === '')).toHaveLength(0);
  });

  test('handles whitespace-only extra args', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      extraArgs: '   ',
      files: '.'
    });

    // Should not contain empty strings
    expect(args.filter(arg => arg === '')).toHaveLength(0);
  });

  test('handles extra args with multiple spaces', () => {
    const args = buildArgs({
      concurrency: '20',
      autoDiscovery: 'true',
      extraArgs: '--verbose    --dry-run',
      files: '.'
    });

    expect(args).toContain('--verbose');
    expect(args).toContain('--dry-run');
    expect(args.filter(arg => arg === '')).toHaveLength(0);
  });

  test('builds full command with all options', () => {
    const args = buildArgs({
      concurrency: '10',
      logs: 'true',
      autoDiscovery: 'true',
      ignoredPaths: 'node_modules/**',
      service: 'test-service',
      extraArgs: '--verbose',
      files: 'custom-path/**'
    });

    expect(args).toEqual([
      'junit', 'upload',
      '--max-concurrency', '10',
      '--logs',
      '--auto-discovery',
      '--ignored-paths', 'node_modules/**',
      '--service', 'test-service',
      '--verbose',
      'custom-path/**'
    ]);
  });

  test('uses custom concurrency value', () => {
    const args = buildArgs({
      concurrency: '5',
      autoDiscovery: 'true',
      files: '.'
    });

    expect(args).toContain('--max-concurrency');
    expect(args).toContain('5');
  });
});

describe('buildEnv', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  test('sets required env vars', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com'
    });

    expect(env.DD_API_KEY).toBe('test-key');
    expect(env.DD_SITE).toBe('datadoghq.com');
  });

  test('sets optional DD_ENV when provided', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com',
      env: 'staging'
    });

    expect(env.DD_ENV).toBe('staging');
  });

  test('sets optional DD_TAGS when provided', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com',
      tags: 'team:backend,region:us-east'
    });

    expect(env.DD_TAGS).toBe('team:backend,region:us-east');
  });

  test('does not set DD_ENV when not provided', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com'
    });

    expect(env.DD_ENV).toBeUndefined();
  });

  test('does not set DD_TAGS when not provided', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com'
    });

    expect(env.DD_TAGS).toBeUndefined();
  });

  test('sets all env vars when all inputs provided', () => {
    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.eu',
      env: 'production',
      tags: 'team:backend'
    });

    expect(env.DD_API_KEY).toBe('test-key');
    expect(env.DD_SITE).toBe('datadoghq.eu');
    expect(env.DD_ENV).toBe('production');
    expect(env.DD_TAGS).toBe('team:backend');
  });

  test('preserves existing environment variables', () => {
    process.env.EXISTING_VAR = 'existing-value';

    const env = buildEnv({
      apiKey: 'test-key',
      site: 'datadoghq.com'
    });

    expect(env.EXISTING_VAR).toBe('existing-value');
  });

  test('handles different Datadog sites', () => {
    const sites = ['datadoghq.com', 'datadoghq.eu', 'us3.datadoghq.com', 'us5.datadoghq.com'];

    sites.forEach(site => {
      const env = buildEnv({
        apiKey: 'test-key',
        site
      });

      expect(env.DD_SITE).toBe(site);
    });
  });
});

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
