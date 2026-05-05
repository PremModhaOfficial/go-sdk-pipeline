# Profile-no-surprise check (G109)

Declared hot paths: ['CPU profile of a miniredis-backed Get bench actually shows — runtime', 'Declared hot paths for G109 (profile-no-surprise). These are what a', 'Get', 'Put', 'Syscall6', 'applyKeyPrefix', 'fill', 'findRunnable', 'futex', 'instrumentedCall', 'mapErr', 'nextFreeFast', 'process', 'readLine', 'runThroughCircuit', 'stealWork', "syscall + scheduler + go-redis reader path — plus the pipeline's own", 'wrapper helpers that may rise in a future profile.', 'writeHeapBitsSmall']
Top-10 total flat% = 62.80
Declared coverage = 58.90 (93.79% of top-10)

Status: PASS

## Top 10 (leaf fn · flat%)
- [✓] internal/runtime/syscall/linux.Syscall6  47.53%
- [✓] runtime.futex  5.53%
- [✓] runtime.stealWork  1.94%
- [✓] runtime.findRunnable  1.35%
- [✓] runtime.nextFreeFast  1.35%
- [✓] runtime.(*mspan).writeHeapBitsSmall  1.2%
- [!] time.runtimeNow  1.2%
- [!] internal/sync.(*Mutex).Lock  1.05%
- [!] sync/atomic.(*Int32).Add  0.9%
- [!] internal/poll.(*fdMutex).rwlock  0.75%