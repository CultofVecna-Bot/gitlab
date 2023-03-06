import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoNodeSyncSettings from 'ee/geo_nodes/components/details/secondary_node/geo_node_sync_settings.vue';
import { MOCK_SECONDARY_SITE } from 'ee_jest/geo_nodes/mock_data';

describe('GeoNodeSyncSettings', () => {
  let wrapper;

  const defaultProps = {
    node: MOCK_SECONDARY_SITE,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(GeoNodeSyncSettings, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findSyncType = () => wrapper.findByTestId('sync-type');
  const findSyncStatusEventInfo = () => wrapper.findByTestId('sync-status-event-info');

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the sync type', () => {
        expect(findSyncType().exists()).toBe(true);
      });
    });

    describe('conditionally', () => {
      describe.each`
        selectiveSyncType | text
        ${null}           | ${'Full'}
        ${'namespaces'}   | ${'Selective (groups)'}
        ${'shards'}       | ${'Selective (shards)'}
      `(`sync type`, ({ selectiveSyncType, text }) => {
        beforeEach(() => {
          createComponent({ node: { selectiveSyncType } });
        });

        it(`renders correctly when selectiveSyncType is ${selectiveSyncType}`, () => {
          expect(findSyncType().text()).toBe(text);
        });
      });

      describe('with no timestamp info', () => {
        beforeEach(() => {
          createComponent({ node: { lastEventTimestamp: null, cursorLastEventTimestamp: null } });
        });

        it('does not render the sync status event info', () => {
          expect(findSyncStatusEventInfo().exists()).toBe(false);
        });
      });

      describe('with timestamp info', () => {
        beforeEach(() => {
          createComponent({
            node: {
              lastEventTimestamp: 1511255300,
              lastEventId: 10,
              cursorLastEventTimestamp: 1511255200,
              cursorLastEventId: 9,
            },
          });
        });

        it('does render the sync status event info', () => {
          expect(findSyncStatusEventInfo().exists()).toBe(true);
          expect(findSyncStatusEventInfo().text()).toBe('20 seconds (1 events)');
        });
      });
    });
  });
});
