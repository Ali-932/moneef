//go:build android || smoke

// Package mobile is the gomobile-bindable entry point for the Moneef Go core
// when embedded inside a Flutter Android app.
//
// All exported function signatures use only the types gomobile bind can
// marshal across the JNI boundary: string, []byte, int64, error, bool.
// Numeric IDs are int64 (gomobile cannot bridge Go's uint). Complex payloads
// flow as JSON bytes in and JSON bytes out.
//
// Init must be called exactly once at app startup (after the Flutter side has
// stored a usable absolute db path). Setup is the only function callable
// before a profile exists. Every other function returns ErrNotInitialized or
// ErrProfileNotSet if called too early.
//
// The whole package is gated by `//go:build android` so `go build ./...`
// outside of gomobile produces zero linkage against the in-process API.
package mobile
