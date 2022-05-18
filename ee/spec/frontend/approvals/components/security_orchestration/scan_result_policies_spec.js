import Vue from 'vue';
import Vuex from 'vuex';
import { GlButton } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { __ } from '~/locale';
import ScanResultPolicies from 'ee/approvals/components/security_orchestration/scan_result_policies.vue';
import securityOrchestrationModule from 'ee/approvals/stores/modules/security_orchestration';
import { gqClient } from 'ee/security_orchestration/utils';
import ScanResultPolicy from 'ee/approvals/components/security_orchestration/scan_result_policy.vue';
import PolicyDetails from 'ee/approvals/components/security_orchestration/policy_details.vue';
import {
  mockScanResultPolicy,
  mockScanResultPolicySecond,
} from '../../../security_orchestration/mocks/mock_data';

Vue.use(Vuex);

const queryResponse = {
  data: {
    project: { scanResultPolicies: { nodes: [mockScanResultPolicy, mockScanResultPolicySecond] } },
  },
};
const emptyQueryResponse = { data: { project: { scanResultPolicies: { nodes: [] } } } };

const NO_SECURITY_POLICIES_MESSAGE = __("You don't have any security policies yet");

describe('ScanResultPolicies', () => {
  let wrapper;
  let store;

  const factory = () => {
    wrapper = mount(ScanResultPolicies, {
      provide: {
        fullPath: 'full/path',
        newPolicyPath: 'policy/new',
        securityPoliciesPath: 'security/path',
      },
      store: new Vuex.Store(store),
    });
  };

  const findAllScanResultPolicies = () => wrapper.findAllComponents(ScanResultPolicy);
  const findAllPolicyDetails = () => wrapper.findAllComponents(PolicyDetails);

  beforeEach(() => {
    store = { modules: { securityOrchestrationModule: securityOrchestrationModule() } };
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when no policy is available', () => {
    beforeEach(() => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(emptyQueryResponse);
      factory();
    });

    it('renders message for the empty state', () => {
      expect(wrapper.text()).toContain(NO_SECURITY_POLICIES_MESSAGE);
    });
  });

  describe('when there are policies are available', () => {
    beforeEach(() => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);
      factory();
    });

    it('renders components related to each policy', () => {
      expect(wrapper.text()).not.toContain(NO_SECURITY_POLICIES_MESSAGE);
      expect(findAllScanResultPolicies()).toHaveLength(2);
      expect(findAllPolicyDetails()).toHaveLength(2);
    });

    describe('when toggle event is generated by the scan result policy', () => {
      it('updates isSelect to the respective policy', async () => {
        expect(wrapper.vm.scanResultPolicies[0].isSelected).toBe(false);
        const scanResultButton = findAllScanResultPolicies().at(0).findComponent(GlButton);
        await scanResultButton.trigger('click');

        expect(wrapper.vm.scanResultPolicies[0].isSelected).toBe(true);
      });
    });
  });

  describe('when it fails to fetch policies', () => {
    beforeEach(() => {
      jest.spyOn(gqClient, 'query').mockRejectedValue();
      factory();
    });

    it('renders message for the empty state', () => {
      expect(wrapper.text()).toContain(NO_SECURITY_POLICIES_MESSAGE);
    });
  });
});
