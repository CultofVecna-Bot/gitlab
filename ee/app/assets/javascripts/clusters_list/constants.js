import { __, s__, sprintf } from '~/locale';

export const MAX_LIST_COUNT = 25;
export const INSTALL_AGENT_MODAL_ID = 'install-agent';
export const ACTIVE_CONNECTION_TIME = 480000;
export const TROUBLESHOOTING_LINK =
  'https://docs.gitlab.com/ee/user/clusters/agent/#troubleshooting';

export const I18N_INSTALL_AGENT_MODAL = {
  next: __('Next'),
  done: __('Done'),
  cancel: __('Cancel'),

  modalTitle: s__('ClusterAgents|Install new Agent'),

  selectAgentTitle: s__('ClusterAgents|Select which Agent you want to install'),
  selectAgentBody: s__(
    `ClusterAgents|Select the Agent you want to register with GitLab and install on your cluster. To learn more about the Kubernetes Agent registration process %{linkStart}go to the documentation%{linkEnd}.`,
  ),

  copyToken: s__('ClusterAgents|Copy token'),
  tokenTitle: s__('ClusterAgents|Registration token'),
  tokenBody: s__(
    `ClusterAgents|The registration token will be used to connect the Agent on your cluster to GitLab. To learn more about the registration tokens and how they are used %{linkStart}go to the documentation%{linkEnd}.`,
  ),

  tokenSingleUseWarningTitle: s__(
    'ClusterAgents|The token value will not be shown again after you close this window.',
  ),
  tokenSingleUseWarningBody: s__(
    `ClusterAgents|The recommended installation method provided below includes the token. If you want to follow the alternative installation method provided in the docs make sure you save the token value before you close the window.`,
  ),

  basicInstallTitle: s__('ClusterAgents|Recommended installation method'),
  basicInstallBody: s__(
    `Open a CLI and connect to the cluster you want to install the Agent in. Use this installation method to minimize any manual steps. The token is already included in the command.`,
  ),

  advancedInstallTitle: s__('ClusterAgents|Alternative installation methods'),
  advancedInstallBody: s__(
    'ClusterAgents|For alternative installation methods %{linkStart}go to the documentation%{linkEnd}.',
  ),

  registrationErrorTitle: s__('Failed to register Agent'),
  unknownError: s__('ClusterAgents|An unknown error occurred. Please try again.'),
};

export const I18N_AVAILABLE_AGENTS_DROPDOWN = {
  selectAgent: s__('ClusterAgents|Select an Agent'),
  registeringAgent: s__('ClusterAgents|Registering Agent'),
};

export const AGENT_STATUSES = {
  active: {
    name: s__('ClusterAgents|Connected'),
    icon: 'status-success',
    class: 'text-success-500',
    tooltip: {
      title: sprintf(s__('ClusterAgents|Last connected %{timeAgo}.')),
    },
  },
  inactive: {
    name: s__('ClusterAgents|Not connected'),
    icon: 'severity-critical',
    class: 'text-danger-800',
    tooltip: {
      title: s__('ClusterAgents|Agent might not be connected to GitLab'),
      body: sprintf(
        s__(
          'ClusterAgents|The Agent has not been connected in a long time. There might be a connectivity issue. Last contact was %{timeAgo}.',
        ),
      ),
    },
  },
  unused: {
    name: s__('ClusterAgents|Never connected'),
    icon: 'status-neutral',
    class: 'text-secondary-400',
    tooltip: {
      title: s__('ClusterAgents|Agent never connected to GitLab'),
      body: s__('ClusterAgents|Make sure you are using a valid token.'),
    },
  },
};
