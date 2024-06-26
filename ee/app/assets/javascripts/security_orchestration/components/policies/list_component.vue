<script>
import { intersection } from 'lodash';
import { GlIcon, GlLink, GlLoadingIcon, GlSprintf, GlTable, GlTooltipDirective } from '@gitlab/ui';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DATE_ONLY_FORMAT } from '~/lib/utils/datetime_utility';
import { getParameterByName, setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import {
  extractTypeParameter,
  extractSourceParameter,
} from 'ee/security_orchestration/components/policies/utils';
import projectScanExecutionPoliciesQuery from '../../graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from '../../graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from '../../graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from '../../graphql/queries/group_scan_result_policies.query.graphql';
import { getPolicyType } from '../../utils';
import DrawerWrapper from '../policy_drawer/drawer_wrapper.vue';
import { isPolicyInherited, policyHasNamespace } from '../utils';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
  POLICY_TYPES_WITH_INHERITANCE,
} from './constants';
import SourceFilter from './filters/source_filter.vue';
import TypeFilter from './filters/type_filter.vue';
import EmptyState from './empty_state.vue';

const NAMESPACE_QUERY_DICT = {
  scanExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectScanExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanExecutionPoliciesQuery,
  },
  scanResult: {
    [NAMESPACE_TYPES.PROJECT]: projectScanResultPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanResultPoliciesQuery,
  },
};

const createPolicyFetchError = ({ gqlError, networkError }) => {
  const error =
    gqlError?.message ||
    networkError?.message ||
    s__('SecurityOrchestration|Something went wrong, unable to fetch policies');
  createAlert({
    message: error,
  });
};

const getPoliciesWithType = (policies, policyType) =>
  policies.map((policy) => ({
    ...policy,
    policyType,
  }));

export default {
  components: {
    GlIcon,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    GlTable,
    EmptyState,
    SourceFilter,
    TypeFilter,
    DrawerWrapper,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: [
    'documentationPath',
    'namespacePath',
    'namespaceType',
    'newPolicyPath',
    'disableScanPolicyUpdate',
  ],
  props: {
    hasPolicyProject: {
      type: Boolean,
      required: false,
      default: false,
    },
    shouldUpdatePolicyList: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  apollo: {
    scanExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanExecution[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanExecutionPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
    scanResultPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanResult[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanResultPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
  },
  data() {
    const selectedPolicySource = extractSourceParameter(getParameterByName('source'));
    const selectedPolicyType = extractTypeParameter(getParameterByName('type'));

    return {
      selectedPolicy: null,
      scanExecutionPolicies: [],
      scanResultPolicies: [],
      selectedPolicySource,
      selectedPolicyType,
    };
  },
  computed: {
    allPolicyTypes() {
      return {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: this.scanExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_RESULT.value]: this.scanResultPolicies,
      };
    },
    policies() {
      let policyTypes =
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value
          ? Object.keys(this.allPolicyTypes)
          : [this.selectedPolicyType];

      if (this.selectedPolicySource === POLICY_SOURCE_OPTIONS.INHERITED.value) {
        policyTypes = intersection(policyTypes, POLICY_TYPES_WITH_INHERITANCE);
      }

      const policies = policyTypes.map((type) =>
        getPoliciesWithType(this.allPolicyTypes[type], POLICY_TYPE_FILTER_OPTIONS[type].text),
      );

      return policies.flat();
    },
    isLoadingPolicies() {
      return (
        this.$apollo.queries.scanExecutionPolicies.loading ||
        this.$apollo.queries.scanResultPolicies.loading
      );
    },
    hasSelectedPolicy() {
      return Boolean(this.selectedPolicy);
    },
    typeLabel() {
      if (this.namespaceType === NAMESPACE_TYPES.GROUP) {
        return this.$options.i18n.groupTypeLabel;
      }
      return this.$options.i18n.projectTypeLabel;
    },
    policyType() {
      // eslint-disable-next-line no-underscore-dangle
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.__typename) : '';
    },
    hasExistingPolicies() {
      return !(
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value &&
        this.selectedPolicySource === POLICY_SOURCE_OPTIONS.ALL.value &&
        !this.policies.length
      );
    },
    fields() {
      return [
        {
          key: 'status',
          label: '',
          thClass: 'gl-w-3',
          tdAttr: {
            'data-testid': 'policy-status-cell',
          },
        },
        {
          key: 'name',
          label: __('Name'),
          thClass: 'gl-w-half',
        },
        {
          key: 'policyType',
          label: s__('SecurityOrchestration|Policy type'),
          sortable: true,
          tdAttr: {
            'data-testid': 'policy-type-cell',
          },
        },
        {
          key: 'source',
          label: s__('SecurityOrchestration|Source'),
          sortable: true,
          tdAttr: {
            'data-testid': 'policy-source-cell',
          },
        },
        {
          key: 'updatedAt',
          label: __('Last modified'),
          sortable: true,
        },
      ];
    },
  },
  watch: {
    shouldUpdatePolicyList(newShouldUpdatePolicyList) {
      // This check prevents an infinite loop of `update-policy-list` being called
      if (newShouldUpdatePolicyList) {
        this.selectedPolicy = null;
        this.$apollo.queries.scanExecutionPolicies.refetch();
        this.$apollo.queries.scanResultPolicies.refetch();
        this.$emit('update-policy-list', {});
      }
    },
  },
  methods: {
    policyListUrlArgs(source) {
      return { namespacePath: source?.namespace?.fullPath || '' };
    },
    getPolicyText(source) {
      return source?.namespace?.name || '';
    },
    getSecurityPolicyListUrl,
    isPolicyInherited,
    policyHasNamespace,
    presentPolicyDrawer(rows) {
      if (rows.length === 0) return;

      const [selectedPolicy] = rows;
      this.selectedPolicy = null;

      /**
       * According to design spec drawer should be closed
       * and opened when drawer content changes
       * it forces drawer to close and open with new content
       */
      this.$nextTick(() => {
        this.selectedPolicy = selectedPolicy;
      });
    },
    deselectPolicy() {
      this.selectedPolicy = null;

      const bTable = this.$refs.policiesTable.$children[0];
      bTable.clearSelected();
    },
    convertFilterValue(defaultValue, value) {
      return value === defaultValue ? undefined : value.toLowerCase();
    },
    setTypeFilter(type) {
      const value = this.convertFilterValue(POLICY_TYPE_FILTER_OPTIONS.ALL.value, type);

      updateHistory({
        url: setUrlParams({ type: value }),
        title: document.title,
        replace: true,
      });

      this.selectedPolicyType = type;
    },
    setSourceFilter(source) {
      const value = this.convertFilterValue(POLICY_SOURCE_OPTIONS.ALL.value, source);

      updateHistory({
        url: setUrlParams({ source: value }),
        title: document.title,
        replace: true,
      });

      this.selectedPolicySource = source;
    },
  },
  dateTimeFormat: DATE_ONLY_FORMAT,
  i18n: {
    inheritedLabel: s__('SecurityOrchestration|Inherited from %{namespace}'),
    inheritedShortLabel: s__('SecurityOrchestration|Inherited'),
    statusEnabled: __('Enabled'),
    statusDisabled: __('Disabled'),
    groupTypeLabel: s__('SecurityOrchestration|This group'),
    projectTypeLabel: s__('SecurityOrchestration|This project'),
  },
};
</script>

<template>
  <div>
    <div class="gl-pt-5 gl-px-5 gl-bg-gray-10">
      <div class="row gl-justify-content-space-between gl-align-items-center">
        <div class="col-12 col-sm-8 col-md-6 col-lg-5 row">
          <type-filter
            :value="selectedPolicyType"
            class="col-6"
            data-testid="policy-type-filter"
            @input="setTypeFilter"
          />
          <source-filter
            :value="selectedPolicySource"
            class="col-6"
            data-testid="policy-source-filter"
            @input="setSourceFilter"
          />
        </div>
      </div>
    </div>

    <gl-table
      ref="policiesTable"
      data-testid="policies-list"
      :busy="isLoadingPolicies"
      :items="policies"
      :fields="fields"
      sort-by="updatedAt"
      sort-desc
      stacked="md"
      show-empty
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      @row-selected="presentPolicyDrawer"
    >
      <template #cell(status)="{ item: { enabled } }">
        <gl-icon
          v-if="enabled"
          v-gl-tooltip="$options.i18n.statusEnabled"
          :aria-label="$options.i18n.statusEnabled"
          name="check-circle-filled"
          class="gl-text-green-700"
        />
        <span v-else class="gl-sr-only">{{ $options.i18n.statusDisabled }}</span>
      </template>

      <template #cell(source)="{ value: source }">
        <gl-sprintf
          v-if="isPolicyInherited(source) && policyHasNamespace(source)"
          :message="$options.i18n.inheritedLabel"
        >
          <template #namespace>
            <gl-link :href="getSecurityPolicyListUrl(policyListUrlArgs(source))" target="_blank">
              {{ getPolicyText(source) }}
            </gl-link>
          </template>
        </gl-sprintf>
        <span v-else-if="isPolicyInherited(source) && !policyHasNamespace(source)">{{
          $options.i18n.inheritedShortLabel
        }}</span>
        <span v-else>{{ typeLabel }}</span>
      </template>

      <template #cell(updatedAt)="{ value: updatedAt }">
        <time-ago-tooltip
          v-if="updatedAt"
          :time="updatedAt"
          :date-time-format="$options.dateTimeFormat"
        />
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>

      <template #empty>
        <empty-state
          :has-existing-policies="hasExistingPolicies"
          :has-policy-project="hasPolicyProject"
        />
      </template>
    </gl-table>

    <drawer-wrapper
      :open="hasSelectedPolicy"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      data-testid="policyDrawer"
      @close="deselectPolicy"
    />
  </div>
</template>
