<script>
import { GlLoadingIcon, GlButton, GlBadge } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import StatusBadge from 'ee/vue_shared/security_reports/components/status_badge.vue';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER, TYPENAME_VULNERABILITY } from '~/graphql_shared/constants';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import download from '~/lib/utils/downloader';
import { redirectTo, visitUrl } from '~/lib/utils/url_utility'; // eslint-disable-line import/no-deprecated
import UsersCache from '~/lib/utils/users_cache';
import { s__ } from '~/locale';
import { REPORT_TYPE_SAST } from '~/vue_shared/security_reports/constants';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import { VULNERABILITY_STATE_OBJECTS, FEEDBACK_TYPES, HEADER_ACTION_BUTTONS } from '../constants';
import { normalizeGraphQLVulnerability, normalizeGraphQLLastStateTransition } from '../helpers';
import ResolutionAlert from './resolution_alert.vue';
import StatusDescription from './status_description.vue';

export default {
  name: 'VulnerabilityHeader',

  components: {
    GlLoadingIcon,
    GlButton,
    GlBadge,
    StatusBadge,
    ResolutionAlert,
    StatusDescription,
    VulnerabilityStateDropdown: () => import('./vulnerability_state_dropdown.vue'),
    SplitButton: () => import('ee/vue_shared/security_reports/components/split_button.vue'),
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
  },

  data() {
    return {
      isProcessingAction: false,
      isLoadingVulnerability: false,
      isLoadingUser: false,
      user: undefined,
      errorAlert: null,
    };
  },

  computed: {
    actionButtons() {
      const buttons = [];

      if (this.canCreateMergeRequest) {
        buttons.push(HEADER_ACTION_BUTTONS.mergeRequestCreation);
      }

      if (this.canDownloadPatch) {
        buttons.push(HEADER_ACTION_BUTTONS.patchDownload);
      }

      if (
        this.glFeatures.resolveVulnerabilityAi &&
        this.vulnerability.reportType === REPORT_TYPE_SAST
      ) {
        buttons.push(HEADER_ACTION_BUTTONS.mergeRequestCreationAi);
      }

      return buttons;
    },
    canDownloadPatch() {
      return (
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state &&
        !this.mergeRequest &&
        this.hasRemediation
      );
    },
    hasIssue() {
      return Boolean(this.vulnerability.issueFeedback?.issueIid);
    },
    hasRemediation() {
      return this.vulnerability.remediations?.[0]?.diff?.length > 0;
    },
    mergeRequest() {
      return this.vulnerability.mergeRequestLinks.at(-1);
    },
    canCreateMergeRequest() {
      return !this.mergeRequest && this.vulnerability.createMrUrl && this.hasRemediation;
    },
    showResolutionAlert() {
      return (
        this.vulnerability.resolvedOnDefaultBranch &&
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state
      );
    },
    initialDismissalReason() {
      return this.vulnerability.stateTransitions?.at(-1)?.dismissalReason;
    },
    disabledChangeState() {
      return !this.vulnerability.canAdmin;
    },
    vulnerabilityGraphqlId() {
      return convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id);
    },
  },
  apollo: {
    $subscribe: {
      aiCompletionResponse: {
        query: aiResponseSubscription,
        skip: true, // We manually start and stop the subscription.
        variables() {
          return {
            resourceId: this.vulnerabilityGraphqlId,
            userId: convertToGraphQLId(TYPENAME_USER, gon.current_user_id),
          };
        },
        async result({ data }) {
          const { errors, content } = data.aiCompletionResponse || {};
          // Once the subscription is ready, we will receive a null aiCompletionResponse. Once we get this, it's safe to
          // start the AI request mutation. Otherwise, it's possible that backend will send the AI response before the
          // subscription is ready, and the AI response will be lost.
          if (!data.aiCompletionResponse) {
            this.resolveVulnerability();
          } else if (errors?.length) {
            this.handleError(errors[0]);
          } else if (content) {
            this.stopSubscription();
            visitUrl(content);
          }
        },
        error(e) {
          this.handleError(e);
        },
      },
    },
  },
  watch: {
    'vulnerability.state': {
      immediate: true,
      handler(state) {
        const id = this.vulnerability[`${state}ById`];

        if (!id) {
          return;
        }

        this.isLoadingUser = true;

        UsersCache.retrieveById(id)
          .then((userData) => {
            this.user = userData;
          })
          .catch(() => {
            createAlert({
              message: s__('VulnerabilityManagement|Something went wrong, could not get user.'),
            });
          })
          .finally(() => {
            this.isLoadingUser = false;
          });
      },
    },
  },

  methods: {
    triggerClick(action) {
      const fn = this[action];
      if (typeof fn === 'function') fn();
    },

    async changeVulnerabilityState({ action, dismissalReason }) {
      this.isLoadingVulnerability = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: vulnerabilityStateMutations[action],
          variables: {
            id: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id),
            dismissalReason,
          },
        });
        const [queryName] = Object.keys(data);

        this.$emit('vulnerability-state-change', {
          ...this.vulnerability,
          ...normalizeGraphQLVulnerability(data[queryName].vulnerability),
          ...normalizeGraphQLLastStateTransition(data[queryName].vulnerability, this.vulnerability),
        });
      } catch (error) {
        createAlert({
          message: {
            error,
            captureError: true,
            message: s__(
              'VulnerabilityManagement|Something went wrong, could not update vulnerability state.',
            ),
          },
        });
      } finally {
        this.isLoadingVulnerability = false;
      }
    },
    resolveVulnerability() {
      this.$apollo
        .mutate({
          mutation: aiActionMutation,
          variables: {
            input: {
              resolveVulnerability: {
                resourceId: this.vulnerabilityGraphqlId,
              },
            },
          },
        })
        .then(({ data }) => {
          const error = data.aiAction.errors[0];
          if (error) {
            this.handleError(error);
          }
        })
        .catch((e) => {
          this.handleError(e.message);
        });
    },

    createMergeRequest() {
      this.isProcessingAction = true;

      const {
        reportType: category,
        pipeline: { sourceBranch },
        projectFingerprint,
        uuid,
      } = this.vulnerability;

      // note: this direct API call will be replaced when migrating the vulnerability details page to GraphQL
      // related epic: https://gitlab.com/groups/gitlab-org/-/epics/3657
      axios
        .post(this.vulnerability.createMrUrl, {
          vulnerability_feedback: {
            feedback_type: FEEDBACK_TYPES.MERGE_REQUEST,
            category,
            project_fingerprint: projectFingerprint,
            finding_uuid: uuid,
            vulnerability_data: {
              ...convertObjectPropsToSnakeCase(this.vulnerability),
              category,
              target_branch: sourceBranch,
            },
          },
        })
        .then(({ data }) => {
          const mergeRequestPath = data.merge_request_links.at(-1).merge_request_path;

          redirectTo(mergeRequestPath); // eslint-disable-line import/no-deprecated
        })
        .catch(() => {
          this.isProcessingAction = false;
          createAlert({
            message: s__(
              'ciReport|There was an error creating the merge request. Please try again.',
            ),
          });
        });
    },
    downloadPatch() {
      download({
        fileData: this.vulnerability.remediations[0].diff,
        fileName: `remediation.patch`,
      });
    },
    startSubscription() {
      this.isProcessingAction = true;
      this.errorAlert?.dismiss();
      this.$apollo.subscriptions.aiCompletionResponse.start();
    },
    stopSubscription() {
      this.$apollo.subscriptions.aiCompletionResponse.stop();
    },
    handleError(error) {
      this.stopSubscription();
      this.isProcessingAction = false;
      this.errorAlert = createAlert({ message: error });
    },
  },
};
</script>

<template>
  <div data-testid="vulnerability-header">
    <resolution-alert
      v-if="showResolutionAlert"
      :vulnerability-id="vulnerability.id"
      :default-branch-name="vulnerability.projectDefaultBranch"
    />
    <div class="detail-page-header">
      <div class="detail-page-header-body" data-testid="vulnerability-detail-body">
        <status-badge
          :state="vulnerability.state"
          :loading="isLoadingVulnerability"
          class="gl-mr-3"
        />
        <status-description
          :vulnerability="vulnerability"
          :user="user"
          :is-loading-vulnerability="isLoadingVulnerability"
          :is-loading-user="isLoadingUser"
        />
      </div>

      <div
        class="detail-page-header-actions gl-display-flex gl-flex-wrap gl-gap-3 gl-align-items-center"
      >
        <label class="gl-mb-0">{{ __('Status') }}</label>
        <gl-loading-icon v-if="isLoadingVulnerability" size="sm" class="gl-display-inline" />
        <vulnerability-state-dropdown
          v-else
          :state="vulnerability.state"
          :dismissal-reason="initialDismissalReason"
          :disabled="disabledChangeState"
          @change="changeVulnerabilityState"
        />
        <split-button
          v-if="actionButtons.length > 1"
          :buttons="actionButtons"
          :disabled="isProcessingAction"
          @createMergeRequest="createMergeRequest"
          @downloadPatch="downloadPatch"
          @startSubscription="startSubscription"
        />
        <gl-button
          v-else-if="actionButtons.length > 0"
          :icon="actionButtons[0].icon"
          class="gl-ml-2"
          variant="confirm"
          :category="actionButtons[0].badge ? 'primary' : 'secondary'"
          :loading="isProcessingAction"
          @click="triggerClick(actionButtons[0].action)"
        >
          {{ actionButtons[0].name }}
          <gl-badge v-if="actionButtons[0].badge" class="gl-ml-1" size="sm" variant="info">
            {{ actionButtons[0].badge }}
          </gl-badge>
        </gl-button>
      </div>
    </div>
  </div>
</template>
