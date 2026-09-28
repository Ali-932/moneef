//go:build android || smoke

package background

// Run completes derived database writes on Android's serial native worker.
// An icon update must not outlive its mutation and race a backup or DB restore.
func Run(task func()) { task() }
