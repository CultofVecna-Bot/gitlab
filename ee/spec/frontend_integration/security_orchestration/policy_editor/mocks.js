import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

export const DEFAULT_PROVIDE = {
  disableScanPolicyUpdate: false,
  disableSecurityPolicyProject: false,
  policyEditorEmptyStateSvgPath: 'path/to/svg',
  namespaceId: 1,
  namespacePath: 'path/to/project',
  namespaceType: NAMESPACE_TYPES.PROJECT,
  scanPolicyDocumentationPath: 'path/to/policy-docs',
  scanResultPolicyApprovers: {
    user: [{ id: 1, username: 'the.one', state: 'active' }],
    group: [],
    role: [],
  },
  assignedPolicyProject: {},
  createAgentHelpPath: 'path/to/agent-docs',
  globalGroupApproversEnabled: false,
  maxActiveScanExecutionPoliciesReached: false,
  maxActiveScanResultPoliciesReached: false,
  maxScanExecutionPoliciesAllowed: 5,
  maxScanResultPoliciesAllowed: 5,
  policiesPath: 'path/to/policies',
  policyType: 'scan_execution',
  roleApproverTypes: [],
  rootNamespacePath: 'path/to/root',
  parsedSoftwareLicenses: [],
  timezones: [],
};
