#ifndef BANGUMI_CRASH_HANDLER_H_
#define BANGUMI_CRASH_HANDLER_H_

// The same executable can write a dump from a separate, minimal process.
// Returns true only when invoked in that private helper mode.
bool RunCrashDumpHelper(int* exit_code);
void StartNativeDiagnostics();
void FinishNativeDiagnostics();

// Declare before Flutter objects so the normal-exit marker is removed only
// after their native destructors have finished.
class NativeDiagnosticsSession {
 public:
  NativeDiagnosticsSession() { StartNativeDiagnostics(); }
  ~NativeDiagnosticsSession() { FinishNativeDiagnostics(); }
};

#endif  // BANGUMI_CRASH_HANDLER_H_
