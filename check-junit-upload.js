'use strict'

const { client, v2 } = require("@datadog/datadog-api-client")

const configuration = client.createConfiguration();
const apiInstance = new v2.CIVisibilityTestsApi(configuration);

const EXPECTED_NUM_TESTS = 32

const params = {
  filterQuery: `@test.service:${process.env.DD_SERVICE} @git.commit.sha:${process.env.GITHUB_SHA}`,
  filterFrom: new Date(new Date().getTime() + -300 * 1000), // Last 5 minutes
  filterTo: new Date(),
  pageLimit: 5,
};

const CHECK_INTERVAL_SECONDS = 10
const MAX_NUM_ATTEMPTS = 10

function getTestData (extraFilter) {
  const finalFilterQuery = `${params.filterQuery} ${extraFilter}`
  console.log(`🔎 Querying CI Visibility tests with ${finalFilterQuery}.`)
  return apiInstance
    .listCIAppTestEvents({
      ...params,
      filterQuery: `${finalFilterQuery}`,
    })
    .then(data => data.data)
    .catch(error => console.error(error))
}

function waitFor (waitSeconds) {
  return new Promise(resolve => setTimeout(() => resolve(), waitSeconds * 1000))
} 

async function checkJunitUpload () {
  let numAttempts = 0
  let isSuccess = false
  let data = []
  while (numAttempts++ < MAX_NUM_ATTEMPTS && !isSuccess) {
    data = await getTestData(`test_level:test ${process.env.EXTRA_TAGS}`)
    if (data.length === EXPECTED_NUM_TESTS) {
      isSuccess = true
    } else {
      const isLastAttempt = numAttempts === MAX_NUM_ATTEMPTS
      if (!isLastAttempt) {
        console.log(`🔁 Attempt number ${numAttempts} failed, retrying in ${CHECK_INTERVAL_SECONDS} seconds.`)
        await waitFor(CHECK_INTERVAL_SECONDS)
      }
    }
  }
  if (isSuccess) {
    console.log(`✅ Successful check: the API returned ${data.length} tests.`)
    process.exit(0)
  } else {
    console.log(`❌ Failed check: the API returned ${data.length} tests but ${EXPECTED_NUM_TESTS} were expected.`)
    process.exit(1)
  }
}

checkJunitUpload()