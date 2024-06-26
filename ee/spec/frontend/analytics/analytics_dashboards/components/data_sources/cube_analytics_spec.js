import { CubejsApi, HttpTransport, __setMockLoad } from '@cubejs-client/core';
import { fetch } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import { pikadayToString } from '~/lib/utils/datetime_utility';
import {
  mockResultSet,
  mockFilters,
  mockTableWithLinksResultSet,
  mockResultSetWithNullValues,
} from '../../mock_data';

const mockLoad = jest.fn().mockImplementation(() => mockResultSet);

jest.mock('~/lib/utils/csrf', () => ({
  headerKey: 'mock-csrf-header',
  token: 'mock-csrf-token',
}));

const itSetsUpCube = () => {
  it('creates a new CubejsApi connection', () => {
    expect(CubejsApi).toHaveBeenCalledWith('1', { transport: {} });
  });

  it('creates a new HttpTransport with the proxy URL and csrf headers', () => {
    expect(HttpTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        apiUrl: '/api/v4/projects/TEST_ID/product_analytics/request',
        headers: expect.objectContaining({
          'mock-csrf-header': 'mock-csrf-token',
        }),
      }),
    );
  });
};

describe('Cube Analytics Data Source', () => {
  beforeEach(() => {
    __setMockLoad(mockLoad);
  });
  const projectId = 'TEST_ID';
  const visualizationType = 'LineChart';
  const query = { measures: ['TrackedEvents.count'] };
  const queryOverrides = { measures: ['TrackedEvents.userLanguage'] };
  const cubeJsOptions = { castNumerics: true };

  describe('fetch', () => {
    beforeEach(() => {
      return fetch({ projectId, visualizationType, query, queryOverrides });
    });

    itSetsUpCube();

    it('loads the query with the query override', () => {
      expect(mockLoad).toHaveBeenCalledWith(queryOverrides, cubeJsOptions);
    });

    describe('formats the data', () => {
      describe('charts', () => {
        it('returns the expected data format for line charts', async () => {
          const result = await fetch({ projectId, visualizationType, query });

          expect(result[0]).toMatchObject({
            data: [
              ['2022-11-09T00:00:00.000', 55],
              ['2022-11-10T00:00:00.000', 14],
            ],
            name: 'pageview, TrackedEvents Count',
          });
        });

        it('returns the expected data format for column charts', async () => {
          const result = await fetch({ projectId, visualizationType: 'ColumnChart', query });

          expect(result[0]).toMatchObject({
            data: [
              ['2022-11-09T00:00:00.000', 55],
              ['2022-11-10T00:00:00.000', 14],
            ],
            name: 'pageview, TrackedEvents Count',
          });
        });
      });

      describe('data tables', () => {
        it('returns the expected data format for', async () => {
          const result = await fetch({ projectId, visualizationType: 'DataTable', query });

          expect(result[0]).toMatchObject({
            count: '55',
            event_type: 'pageview',
            utc_time: '2022-11-09T00:00:00.000',
          });
        });

        it('returns the expected data format when links config is defined', async () => {
          mockLoad.mockImplementationOnce(() => mockTableWithLinksResultSet);

          const result = await fetch({
            projectId,
            visualizationType: 'DataTable',
            query: {
              measures: ['TrackedEvents.pageViewsCount'],
              dimensions: ['TrackedEvents.docPath', 'TrackedEvents.url'],
            },
            visualizationOptions: {
              links: [
                {
                  text: 'TrackedEvents.docPath',
                  href: 'TrackedEvents.url',
                },
              ],
            },
          });

          expect(result[0]).toMatchObject({
            page_views_count: '1',
            doc_path: {
              text: '/foo',
              href: 'https://example.com/foo',
            },
          });
        });
      });

      describe('single stats', () => {
        it('returns the expected data format', async () => {
          const result = await fetch({ projectId, visualizationType: 'SingleStat', query });

          expect(result).toBe('36');
        });

        it('returns the expected data format with custom measure', async () => {
          const override = { measures: ['TrackedEvents.url'] };
          const result = await fetch({
            projectId,
            visualizationType: 'SingleStat',
            query,
            queryOverrides: override,
          });

          expect(result).toBe('https://example.com/us');
        });

        it('returns 0 when the measure is null', async () => {
          mockLoad.mockImplementationOnce(() => mockResultSetWithNullValues);

          const result = await fetch({
            projectId,
            visualizationType: 'SingleStat',
            query,
          });

          expect(result).toBe(0);
        });
      });
    });
  });

  describe('fetch with filters', () => {
    const existingFilters = [
      {
        operator: 'equals',
        values: ['pageview'],
        member: 'TrackedEvents.eventType',
      },
    ];

    const fetchWithFilters = (measure, filters) =>
      fetch({
        projectId,
        visualizationType,
        query: {
          filters: existingFilters,
          measures: [measure],
        },
        queryOverrides: {},
        filters,
      });

    it.each`
      type               | queryMeasurement                 | expectedDimension
      ${'TrackedEvents'} | ${'TrackedEvents.pageViewCount'} | ${'TrackedEvents.derivedTstamp'}
      ${'Sessions'}      | ${'Sessions.pageViewCount'}      | ${'Sessions.startAt'}
    `(
      'loads the query with date range filters for "$type"',
      async ({ queryMeasurement, expectedDimension }) => {
        await fetchWithFilters(queryMeasurement, mockFilters);

        expect(mockLoad).toHaveBeenCalledWith(
          expect.objectContaining({
            filters: [
              ...existingFilters,
              {
                member: expectedDimension,
                operator: 'inDateRange',
                values: [
                  pikadayToString(mockFilters.startDate),
                  pikadayToString(mockFilters.endDate),
                ],
              },
            ],
          }),
          cubeJsOptions,
        );
      },
    );

    describe('filtering anon users', () => {
      it.each`
        type                | queryMeasurement                  | expectedSegments
        ${'TrackedEvents'}  | ${'TrackedEvents.pageViewCount'}  | ${{ segments: ['TrackedEvents.knownUsers'] }}
        ${'Sessions'}       | ${'Sessions.pageViewCount'}       | ${{}}
        ${'ReturningUsers'} | ${'ReturningUsers.pageViewCount'} | ${{}}
      `(
        'segments the query with "$expectedSegments" for "$type"',
        async ({ queryMeasurement, expectedSegments }) => {
          await fetchWithFilters(queryMeasurement, { filterAnonUsers: true });

          expect(mockLoad).toHaveBeenCalledWith(
            {
              filters: existingFilters,
              measures: [queryMeasurement],
              ...expectedSegments,
            },
            cubeJsOptions,
          );
        },
      );
    });
  });
});
