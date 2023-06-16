import { __, n__, s__, sprintf } from '~/locale';
import { getDateInPast, getCurrentUtcDate } from '~/lib/utils/datetime_utility';

export const TODAY = getCurrentUtcDate();

export const CUSTOM_DATE_RANGE_KEY = 'custom';

/**
 * The default options to display in the date_range_filter.
 *
 * Each options consists of:
 *
 * key - The key used to select the option and sync with the URL
 * text - Text to display in the dropdown item
 * startDate - Optional, the start date to set
 * endDate - Optional, the end date to set
 * showDateRangePicker - Optional, show the date range picker component and uses
 *                       it to set the date.
 */
export const DATE_RANGE_OPTIONS = [
  {
    key: 'last_30_days',
    text: sprintf(__('Last %{days} days'), { days: 30 }),
    startDate: getDateInPast(TODAY, 30),
    endDate: TODAY,
  },
  {
    key: 'last_7_days',
    text: sprintf(__('Last %{days} days'), { days: 7 }),
    startDate: getDateInPast(TODAY, 7),
    endDate: TODAY,
  },
  {
    key: 'today',
    text: __('Today'),
    startDate: TODAY,
    endDate: TODAY,
  },
  {
    key: CUSTOM_DATE_RANGE_KEY,
    text: __('Custom range'),
    showDateRangePicker: true,
  },
];

export const I18N_DATE_RANGE_FILTER_TOOLTIP = (dateRangeLimit = 0) =>
  n__('Date range limited to %d day', 'Date range limited to %d days', dateRangeLimit);
export const I18N_DATE_RANGE_FILTER_TO = __('To');
export const I18N_DATE_RANGE_FILTER_FROM = __('From');
export const I18N_DATE_RANGE_TIMEZONE_TOOLTIP = s__(
  'Analytics|Dates and times are displayed in the UTC timezone',
);

export const DEFAULT_SELECTED_OPTION_INDEX = 1;
