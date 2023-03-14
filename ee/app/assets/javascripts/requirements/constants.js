import { __, s__ } from '~/locale';

export const FilterState = {
  opened: 'OPENED',
  archived: 'ARCHIVED',
  all: 'ALL',
};

export const FilterStateEmptyMessage = {
  OPENED: __('There are no open requirements'),
  ARCHIVED: __('There are no archived requirements'),
};

export const AvailableSortOptions = [
  {
    id: 1,
    title: __('Created date'),
    sortDirection: {
      descending: 'created_desc',
      ascending: 'created_asc',
    },
  },
  {
    id: 2,
    title: __('Updated date'),
    sortDirection: {
      descending: 'updated_desc',
      ascending: 'updated_asc',
    },
  },
];

export const TestReportStatus = {
  Passed: 'PASSED',
  Failed: 'FAILED',
};

export const TestReportStatusToValue = {
  satisfied: 'PASSED',
  failed: 'FAILED',
  missing: 'MISSING',
};

export const I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_TITLE = s__(
  'Requirement|Legacy requirement ID: %{legacyId}',
);

export const I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_POPOVER = s__(
  `Requirement|Legacy requirement IDs are being deprecated. Update your links to reference this item's new ID %{id}. %{linkStart}Learn more%{linkEnd}.`,
);

export const I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_DETAIL = s__(
  `Requirement|Requirements have become work items and the legacy requirement IDs are being deprecated. Update your links to reference this item's new ID %{id}. %{linkStart}Learn more%{linkEnd}.`,
);
