import * as mockData from '../../../frontend/vue_shared/security_reports/mock_data';

// This is done to help keep the mock data across testing suites in sync.
// https://gitlab.com/gitlab-org/gitlab/merge_requests/10466#note_156218753

export const {
  allIssuesParsed,
  baseIssues,
  containerScanningFeedbacks,
  dast,
  dastBase,
  dastFeedbacks,
  dependencyScanningFeedbacks,
  dependencyScanningIssues,
  dependencyScanningIssuesBase,
  dependencyScanningIssuesMajor2,
  dependencyScanningIssuesOld,
  dockerBaseReport,
  dockerNewIssues,
  dockerOnlyHeadParsed,
  dockerReport,
  dockerReportParsed,
  oldSastIssues,
  parsedDast,
  parsedDastNewIssues,
  parsedDependencyScanningBaseStore,
  parsedDependencyScanningIssuesHead,
  parsedDependencyScanningIssuesStore,
  parsedSastBaseStore,
  parsedSastContainerBaseStore,
  parsedSastIssuesHead,
  parsedSastIssuesStore,
  sastBaseAllIssues,
  sastFeedbacks,
  sastHeadAllIssues,
  sastIssues,
  sastIssuesBase,
  sastIssuesMajor2,
  sastParsedIssues,
} = mockData;
