export const compactJobLog = (jobLog) => {
  const compactedLog = [];

  jobLog.forEach((obj) => {
    // push header section line
    if (obj.line && obj.isHeader) {
      compactedLog.push(obj.line);
    }

    // push lines within section header
    if (obj.lines?.length > 0) {
      compactedLog.push(...obj.lines);
    }

    // push lines from plain log
    if (!obj.lines && obj.content.length > 0) {
      compactedLog.push(obj);
    }
  });

  return compactedLog;
};
