//go:build android

package config

import (
	"flag"
	"io"
	"log"
	"os"
	"path/filepath"
)

// SetUpLogs configures process-wide logging on Android. The CWD inside an
// Android process is read-only, so the log file is created under the writable
// user-config directory (which is also where the SQLite file lives). If the
// directory or file cannot be opened we fall back to stdout-only logging
// rather than crashing — a missing log file must never take the app down on
// device.
func SetUpLogs() *os.File {
	if flag.Lookup("test.v") != nil {
		log.SetOutput(io.Discard)
		return nil
	}
	configDir, err := os.UserConfigDir()
	if err != nil {
		log.SetOutput(os.Stdout)
		log.Printf("SetUpLogs: cannot determine user config dir, stdout only: %v", err)
		return nil
	}
	logDir := filepath.Join(configDir, "moneef")
	if err := os.MkdirAll(logDir, 0755); err != nil {
		log.SetOutput(os.Stdout)
		log.Printf("SetUpLogs: cannot create log dir %q, stdout only: %v", logDir, err)
		return nil
	}
	logPath := filepath.Join(logDir, "app.log")
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.SetOutput(os.Stdout)
		log.Printf("SetUpLogs: cannot open %q, stdout only: %v", logPath, err)
		return nil
	}
	multiWriter := io.MultiWriter(os.Stdout, file)
	log.SetOutput(multiWriter)
	log.Printf("Log is ready at %s", logPath)
	return file
}
