<script>
import { GlEmptyState } from '@gitlab/ui';
import { isUndefined } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';

import { __ } from '~/locale';
import { InternalEvents } from '~/tracking';
import InsightsChart from './insights_chart.vue';

export default {
  components: {
    GlEmptyState,
    InsightsChart,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    queryEndpoint: {
      type: String,
      required: true,
    },
    pageConfig: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapState('insights', ['chartData']),
    emptyState() {
      return {
        title: __('There are no charts configured for this page'),
        description: __(
          'Please check the configuration file to ensure that a collection of charts has been declared.',
        ),
      };
    },
    charts() {
      return this.pageConfig.charts;
    },
    chartKeys() {
      return this.charts.map((chart) => chart.title);
    },
    hasChartsConfigured() {
      return !isUndefined(this.charts) && this.charts.length > 0;
    },
  },
  watch: {
    pageConfig() {
      this.fetchCharts();
    },
  },
  mounted() {
    this.fetchCharts();
  },
  methods: {
    ...mapActions('insights', ['fetchChartData', 'initChartData']),
    fetchCharts() {
      if (this.hasChartsConfigured) {
        this.initChartData(this.chartKeys);

        this.charts.forEach((chart) =>
          this.fetchChartData({ endpoint: this.queryEndpoint, chart }),
        );
      }
    },
    onChartItemClicked() {
      this.trackEvent('insights_chart_item_clicked');
      this.trackEvent(`insights_issue_chart_item_clicked`); // hardcode data source type `issue` until more chart types support drilling down
    },
  },
};
</script>
<template>
  <div class="insights-page" data-testid="insights-page">
    <div v-if="hasChartsConfigured" class="js-insights-page-container">
      <h4 class="text-center">{{ pageConfig.title }}</h4>
      <div class="insights-charts" data-testid="insights-charts">
        <insights-chart
          v-for="(
            { loaded, type, description, data, dataSourceType, error }, key, index
          ) in chartData"
          :key="index"
          :loaded="loaded"
          :type="type"
          :title="key"
          :description="description"
          :data="data"
          :data-source-type="dataSourceType"
          :error="error"
          @chart-item-clicked="onChartItemClicked"
        />
      </div>
    </div>
    <gl-empty-state
      v-else
      :title="emptyState.title"
      :description="emptyState.description"
      svg-path="/assets/illustrations/monitoring/getting_started.svg"
      :svg-height="null"
    />
  </div>
</template>
