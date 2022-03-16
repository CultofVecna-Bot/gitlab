import { GlDropdown, GlDropdownItem, GlDropdownSectionHeader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ClustersActions from '~/clusters_list/components/clusters_actions.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { INSTALL_AGENT_MODAL_ID, CLUSTERS_ACTIONS } from '~/clusters_list/constants';

describe('ClustersActionsComponent', () => {
  let wrapper;

  const newClusterPath = 'path/to/add/cluster';
  const addClusterPath = 'path/to/connect/existing/cluster';
  const createClusterPath = 'path/to/create/new/cluster';

  const defaultProvide = {
    newClusterPath,
    addClusterPath,
    createClusterPath,
    canAddCluster: true,
    displayClusterAgents: true,
    certificateBasedClustersEnabled: true,
  };

  const findDropdown = () => wrapper.findComponent(GlDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDropdownItem);
  const findDropdownItemIds = () =>
    findDropdownItems().wrappers.map((x) => x.attributes('data-testid'));
  const findAllSectionHeaders = () => wrapper.findAllComponents(GlDropdownSectionHeader);
  const findSectionHeadersTexts = () => findAllSectionHeaders().wrappers.map((x) => x.text());
  const findNewClusterLink = () => wrapper.findByTestId('new-cluster-link');
  const findConnectClusterLink = () => wrapper.findByTestId('connect-cluster-link');
  const findConnectNewAgentLink = () => wrapper.findByTestId('connect-new-agent-link');

  const createWrapper = (provideData = {}) => {
    wrapper = shallowMountExtended(ClustersActions, {
      provide: {
        ...defaultProvide,
        ...provideData,
      },
      directives: {
        GlModalDirective: createMockDirective(),
        GlTooltip: createMockDirective(),
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  afterEach(() => {
    wrapper.destroy();
  });
  describe('when the certificate based clusters are enabled', () => {
    it('renders actions menu', () => {
      expect(findDropdown().props('text')).toBe(CLUSTERS_ACTIONS.actionsButton);
    });

    it('renders correct href attributes for the links', () => {
      expect(findNewClusterLink().attributes('href')).toBe(newClusterPath);
      expect(findConnectClusterLink().attributes('href')).toBe(addClusterPath);
    });

    describe('when user cannot add clusters', () => {
      beforeEach(() => {
        createWrapper({ canAddCluster: false });
      });

      it('disables dropdown', () => {
        expect(findDropdown().props('disabled')).toBe(true);
      });

      it('shows tooltip explaining why dropdown is disabled', () => {
        const tooltip = getBinding(findDropdown().element, 'gl-tooltip');
        expect(tooltip.value).toBe(CLUSTERS_ACTIONS.dropdownDisabledHint);
      });

      it('does not bind split dropdown button', () => {
        const binding = getBinding(findDropdown().element, 'gl-modal-directive');

        expect(binding.value).toBe(false);
      });
    });

    describe('when on project level', () => {
      it('renders a dropdown with 3 actions items', () => {
        expect(findDropdownItemIds()).toEqual([
          'connect-new-agent-link',
          'create-cluster-link',
          'new-cluster-link',
          'connect-cluster-link',
        ]);
      });

      it('renders proper section headers', () => {
        expect(findSectionHeadersTexts()).toEqual([
          CLUSTERS_ACTIONS.agent,
          CLUSTERS_ACTIONS.certificate,
        ]);
      });

      it('renders correct modal id for the agent link', () => {
        const binding = getBinding(findConnectNewAgentLink().element, 'gl-modal-directive');

        expect(binding.value).toBe(INSTALL_AGENT_MODAL_ID);
      });

      it('shows tooltip', () => {
        const tooltip = getBinding(findDropdown().element, 'gl-tooltip');
        expect(tooltip.value).toBe(CLUSTERS_ACTIONS.connectWithAgent);
      });

      it('shows split button in dropdown', () => {
        expect(findDropdown().props('split')).toBe(true);
      });

      it('binds split button with modal id', () => {
        const binding = getBinding(findDropdown().element, 'gl-modal-directive');

        expect(binding.value).toBe(INSTALL_AGENT_MODAL_ID);
      });
    });

    describe('when on group or admin level', () => {
      beforeEach(() => {
        createWrapper({ displayClusterAgents: false });
      });

      it('renders a dropdown with 2 actions items', () => {
        expect(findDropdownItemIds()).toEqual(['new-cluster-link', 'connect-cluster-link']);
      });

      it("doesn't render section headers", () => {
        expect(findAllSectionHeaders()).toHaveLength(0);
      });

      it('shows tooltip', () => {
        const tooltip = getBinding(findDropdown().element, 'gl-tooltip');
        expect(tooltip.value).toBe(CLUSTERS_ACTIONS.connectExistingCluster);
      });

      it('does not show split button in dropdown', () => {
        expect(findDropdown().props('split')).toBe(false);
      });

      it('does not bind dropdown button to modal', () => {
        const binding = getBinding(findDropdown().element, 'gl-modal-directive');

        expect(binding.value).toBe(false);
      });
    });
  });

  describe('when the certificate based clusters not enabled', () => {
    beforeEach(() => {
      createWrapper({ certificateBasedClustersEnabled: false });
    });

    it('renders a dropdown with 2 actions items', () => {
      expect(findDropdownItemIds()).toEqual(['connect-new-agent-link', 'create-cluster-link']);
    });

    it("doesn't render section headers", () => {
      expect(findAllSectionHeaders()).toHaveLength(0);
    });
  });
});
