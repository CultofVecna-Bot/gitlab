import {
  findIssueIndex,
  groupedTextBuilder,
  statusIcon,
  countVulnerabilities,
  groupedReportText,
} from 'ee/vue_shared/security_reports/store/utils';
import convertReportType from 'ee/vue_shared/security_reports/store/utils/convert_report_type';
import getFileLocation from 'ee/vue_shared/security_reports/store/utils/get_file_location';
import {
  CRITICAL,
  HIGH,
  MEDIUM,
  LOW,
} from 'ee/security_dashboard/store/modules/vulnerabilities/constants';
import getPrimaryIdentifiers from 'ee/vue_shared/security_reports/store/utils/get_primary_identifier';

describe('security reports utils', () => {
  describe('findIssueIndex', () => {
    let issuesList;

    beforeEach(() => {
      issuesList = [
        { project_fingerprint: 'abc123' },
        { project_fingerprint: 'abc456' },
        { project_fingerprint: 'abc789' },
      ];
    });

    it('returns index of found issue', () => {
      const issue = {
        project_fingerprint: 'abc456',
      };

      expect(findIssueIndex(issuesList, issue)).toEqual(1);
    });

    it('returns -1 when issue is not found', () => {
      const issue = {
        project_fingerprint: 'foo',
      };

      expect(findIssueIndex(issuesList, issue)).toEqual(-1);
    });
  });

  describe('convertReportType', () => {
    it.each`
      reportType               | output
      ${'sast'}                | ${'SAST'}
      ${'dependency_scanning'} | ${'Dependency Scanning'}
      ${'CONTAINER_SCANNING'}  | ${'Container Scanning'}
      ${'CUSTOM_SCANNER'}      | ${'Custom scanner'}
      ${'mast'}                | ${'Mast'}
      ${'TAST'}                | ${'Tast'}
      ${undefined}             | ${''}
    `(
      'converts the report type "$reportType" to the human-readable string "$output"',
      ({ reportType, output }) => {
        expect(convertReportType(reportType)).toEqual(output);
      },
    );
  });

  describe('getFileLocation', () => {
    const hostname = 'https://hostna.me';
    const path = '/deeply/nested/route';

    it('should return the correct location when passed both a hostname and a path', () => {
      const result = getFileLocation({ hostname, path });

      expect(result).toEqual(`${hostname}${path}`);
    });

    it('should return null if the hostname is not present', () => {
      const result = getFileLocation({ path });

      expect(result).toBeNull();
    });

    it('should return null if the path is not present', () => {
      const result = getFileLocation({ hostname });

      expect(result).toBeNull();
    });

    it('should return null if the argument is undefined', () => {
      const result = getFileLocation(undefined);

      expect(result).toBeNull();
    });
  });

  describe('getPrimaryIdentifier', () => {
    const identifiers = [
      { external_type: 'cve', name: 'CVE-1337' },
      { external_type: 'gemnaisum', name: 'GEMNASIUM-1337' },
    ];
    it('should return the `cve` identifier if a `cve` identifier does exist', () => {
      expect(getPrimaryIdentifiers(identifiers, 'external_type')).toBe(identifiers[0].name);
    });
    it('should return the first identifier if the property for type does not exist', () => {
      expect(getPrimaryIdentifiers(identifiers, 'externalType')).toBe(identifiers[0].name);
    });
    it('should return the first identifier if a `cve` identifier does not exist', () => {
      expect(getPrimaryIdentifiers([identifiers[1]], 'external_type')).toBe(identifiers[1].name);
    });
    it('should return an empty string if identifiers is empty', () => {
      expect(getPrimaryIdentifiers()).toBe('');
    });
  });

  describe('groupedTextBuilder', () => {
    const critical = 2;
    const high = 4;
    const other = 7;

    it.each`
      vulnerabilities              | message
      ${undefined}                 | ${' detected no new vulnerabilities.'}
      ${{ critical }}              | ${' detected %{criticalStart}2 new critical%{criticalEnd} severity vulnerabilities.'}
      ${{ high }}                  | ${' detected %{highStart}4 new high%{highEnd} severity vulnerabilities.'}
      ${{ other }}                 | ${' detected 7 vulnerabilities.'}
      ${{ critical, high }}        | ${' detected %{criticalStart}2 new critical%{criticalEnd} and %{highStart}4 new high%{highEnd} severity vulnerabilities.'}
      ${{ critical, other }}       | ${' detected %{criticalStart}2 new critical%{criticalEnd} severity vulnerabilities out of 9.'}
      ${{ high, other }}           | ${' detected %{highStart}4 new high%{highEnd} severity vulnerabilities out of 11.'}
      ${{ critical, high, other }} | ${' detected %{criticalStart}2 new critical%{criticalEnd} and %{highStart}4 new high%{highEnd} severity vulnerabilities out of 13.'}
    `('should build the message as "$message"', ({ vulnerabilities, message }) => {
      expect(groupedTextBuilder(vulnerabilities)).toEqual(message);
    });

    it.each`
      vulnerabilities    | message
      ${{ critical: 1 }} | ${' detected %{criticalStart}1 new critical%{criticalEnd} severity vulnerability.'}
      ${{ high: 1 }}     | ${' detected %{highStart}1 new high%{highEnd} severity vulnerability.'}
      ${{ other: 1 }}    | ${' detected 1 vulnerability.'}
    `('should handle single vulnerabilities for "$message"', ({ vulnerabilities, message }) => {
      expect(groupedTextBuilder(vulnerabilities)).toEqual(message);
    });

    it('should pass through the report type', () => {
      const reportType = 'HAL';
      expect(groupedTextBuilder({ reportType })).toEqual('HAL detected no new vulnerabilities.');
    });

    it('should pass through the status', () => {
      const reportType = 'HAL';
      const status = '(is loading)';
      expect(groupedTextBuilder({ reportType, status })).toEqual(
        'HAL (is loading) detected no new vulnerabilities.',
      );
    });
  });

  describe('statusIcon', () => {
    describe('with failed report', () => {
      it('returns warning', () => {
        expect(statusIcon(false, true)).toEqual('warning');
      });
    });

    describe('with new issues', () => {
      it('returns warning', () => {
        expect(statusIcon(false, false, 1)).toEqual('warning');
      });
    });

    describe('with neutral issues', () => {
      it('returns warning', () => {
        expect(statusIcon(false, false, 0, 1)).toEqual('warning');
      });
    });

    describe('without new or neutal issues', () => {
      it('returns success', () => {
        expect(statusIcon()).toEqual('success');
      });
    });
  });

  describe('countVulnerabilities', () => {
    it.each`
      vulnerabilities                                     | response
      ${[]}                                               | ${{ critical: 0, high: 0, other: 0 }}
      ${[{ severity: CRITICAL }, { severity: CRITICAL }]} | ${{ critical: 2, high: 0, other: 0 }}
      ${[{ severity: HIGH }, { severity: HIGH }]}         | ${{ critical: 0, high: 2, other: 0 }}
      ${[{ severity: LOW }, { severity: MEDIUM }]}        | ${{ critical: 0, high: 0, other: 2 }}
      ${[{ severity: CRITICAL }, { severity: HIGH }]}     | ${{ critical: 1, high: 1, other: 0 }}
      ${[{ severity: CRITICAL }, { severity: LOW }]}      | ${{ critical: 1, high: 0, other: 1 }}
    `('should count the vulnerabilities correctly', ({ vulnerabilities, response }) => {
      expect(countVulnerabilities(vulnerabilities)).toEqual(response);
    });
  });

  describe('groupedReportText', () => {
    const reportType = 'dummyReport';
    const errorMessage = 'Something went wrong';
    const loadingMessage = 'The report is still loading';
    const baseReport = { paths: [] };

    it("should return the error message when there's an error", () => {
      const report = { ...baseReport, hasError: true };
      const result = groupedReportText(report, reportType, errorMessage, loadingMessage);

      expect(result).toBe(errorMessage);
    });

    it("should return the loading message when it's loading", () => {
      const report = { ...baseReport, isLoading: true };
      const result = groupedReportText(report, reportType, errorMessage, loadingMessage);

      expect(result).toBe(loadingMessage);
    });

    it("should call groupedTextBuilder if it isn't loading and doesn't have an error", () => {
      const report = { ...baseReport };
      const result = groupedReportText(report, reportType, errorMessage, loadingMessage);

      expect(result).toBe(`${reportType} detected no new vulnerabilities.`);
    });
  });
});
