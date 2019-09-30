import * as types from 'ee/analytics/productivity_analytics/store/modules/charts/mutation_types';
import mutations from 'ee/analytics/productivity_analytics/store/modules/charts/mutations';
import getInitialState from 'ee/analytics/productivity_analytics/store/modules/charts/state';
import { chartKeys } from 'ee/analytics/productivity_analytics/constants';
import { mockHistogramData } from '../../../mock_data';

describe('Productivity analytics chart mutations', () => {
  let state;
  let chartKey = chartKeys.main;

  beforeEach(() => {
    state = getInitialState();
  });

  describe(types.RESET_CHART_DATA, () => {
    it('resets the data and selected items', () => {
      mutations[types.RESET_CHART_DATA](state, chartKey);

      expect(state.charts[chartKey].data).toEqual({});
      expect(state.charts[chartKey].selected).toEqual([]);
    });
  });

  describe(types.REQUEST_CHART_DATA, () => {
    it('sets isLoading to true', () => {
      mutations[types.REQUEST_CHART_DATA](state, chartKey);

      expect(state.charts[chartKey].isLoading).toBe(true);
    });
  });

  describe(types.RECEIVE_CHART_DATA_SUCCESS, () => {
    it('updates relevant chart with data', () => {
      mutations[types.RECEIVE_CHART_DATA_SUCCESS](state, { chartKey, data: mockHistogramData });

      expect(state.charts[chartKey].isLoading).toBe(false);
      expect(state.charts[chartKey].errorCode).toBe(null);
      expect(state.charts[chartKey].data).toEqual(mockHistogramData);
    });
  });

  describe(types.RECEIVE_CHART_DATA_ERROR, () => {
    const status = 500;
    beforeEach(() => {
      mutations[types.RECEIVE_CHART_DATA_ERROR](state, { chartKey, status });
    });

    it('sets errorCode to 500', () => {
      expect(state.charts[chartKey].isLoading).toBe(false);
      expect(state.charts[chartKey].errorCode).toBe(status);
    });

    it('clears data', () => {
      expect(state.charts[chartKey].isLoading).toBe(false);
      expect(state.charts[chartKey].data).toEqual({});
    });
  });

  describe(types.SET_METRIC_TYPE, () => {
    it('updates the metricType on the params', () => {
      chartKey = chartKeys.timeBasedHistogram;
      const metricType = 'time_to_merge';

      mutations[types.SET_METRIC_TYPE](state, { chartKey, metricType });

      expect(state.charts[chartKey].params.metricType).toBe(metricType);
    });
  });

  describe(types.UPDATE_SELECTED_CHART_ITEMS, () => {
    chartKey = chartKeys.timeBasedHistogram;
    const item = 5;

    it('adds the item to the list of selected items when not included', () => {
      mutations[types.UPDATE_SELECTED_CHART_ITEMS](state, { chartKey, item });

      expect(state.charts[chartKey].selected).toEqual([5]);
    });

    it('removes the item from the list of selected items when already included', () => {
      state.charts[chartKey].selected.push(5);

      mutations[types.UPDATE_SELECTED_CHART_ITEMS](state, { chartKey, item });

      expect(state.charts[chartKey].selected).toEqual([]);
    });
  });

  describe(types.SET_CHART_ENABLED, () => {
    chartKey = chartKeys.scatterplot;

    it('sets the enabled flag to true on the scatterplot chart', () => {
      mutations[types.SET_CHART_ENABLED](state, { chartKey, isEnabled: true });

      expect(state.charts[chartKey].enabled).toBe(true);
    });

    it('sets the enabled flag to false on the scatterplot chart', () => {
      mutations[types.SET_CHART_ENABLED](state, { chartKey, isEnabled: false });

      expect(state.charts[chartKey].enabled).toBe(false);
    });
  });
});
