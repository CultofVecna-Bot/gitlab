<script>
import { s__, __ } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { fromYaml } from '../../policy_editor/scan_result/lib';
import { SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import ToggleList from '../toggle_list.vue';
import Approvals from './policy_approvals.vue';
import Settings from './policy_settings.vue';
import { humanizeRules } from './utils';

export default {
  i18n: {
    summary: SUMMARY_TITLE,
    scanResult: s__('SecurityOrchestration|Scan result'),
  },
  components: {
    ToggleList,
    DrawerLayout,
    InfoRow,
    Approvals,
    Settings,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    humanizedRules() {
      return humanizeRules(this.parsedYaml.rules);
    },
    parsedYaml() {
      try {
        return fromYaml({ manifest: this.policy.yaml });
      } catch (e) {
        return null;
      }
    },
    requireApproval() {
      return this.parsedYaml?.actions?.find((action) => action.type === 'require_approval');
    },
    approvers() {
      return [
        ...this.policy.allGroupApprovers,
        ...this.policy.roleApprovers.map((r) => {
          return {
            GUEST: __('Guest'),
            REPORTER: __('Reporter'),
            DEVELOPER: __('Developer'),
            MAINTAINER: __('Maintainer'),
            OWNER: __('Owner'),
          }[r];
        }),
        ...this.policy.userApprovers,
      ];
    },
    settings() {
      return this.parsedYaml?.approval_settings || {};
    },
  },
  methods: {
    capitalizedCriteriaMessage(message) {
      return capitalizeFirstCharacter(message.trim());
    },
    showBranchExceptions(exceptions) {
      return exceptions?.length > 0;
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_result_policy"
    :description="parsedYaml.description"
    :policy="policy"
    :type="$options.i18n.scanResult"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <settings :settings="settings" />
        <approvals :action="requireApproval" :approvers="approvers" />
        <div
          v-for="(
            { summary, branchExceptions, criteriaMessage, criteriaList }, idx
          ) in humanizedRules"
          :key="idx"
          class="gl-pt-5"
        >
          {{ summary }}
          <toggle-list
            v-if="showBranchExceptions(branchExceptions)"
            class="gl-mb-2"
            :items="branchExceptions"
          />
          <p v-if="criteriaMessage" class="gl-mb-3">
            {{ capitalizedCriteriaMessage(criteriaMessage) }}
          </p>
          <ul class="gl-m-0">
            <li v-for="(criteria, criteriaIdx) in criteriaList" :key="criteriaIdx" class="gl-mt-2">
              {{ criteria }}
            </li>
          </ul>
        </div>
      </info-row>
    </template>
  </drawer-layout>
</template>
