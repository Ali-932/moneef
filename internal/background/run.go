//go:build !android && !smoke

package background

// Run keeps server and CLI enrichment work asynchronous.
func Run(task func()) { go task() }
