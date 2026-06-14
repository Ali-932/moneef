//go:build !android

package config

import (
	"flag"
	"io"
	"log"
	"os"
)

// SetUpLogs configures process-wide logging. On desktop / server runtimes the
// log is written to a file `app.log` in the current working directory (matching
// historical behavior). Returns the open *os.File so callers can close it on
// shutdown, or nil under `go test`.
func SetUpLogs() *os.File {
	if flag.Lookup("test.v") != nil {
		log.SetOutput(io.Discard)
		return nil
	}
	file, err := os.OpenFile("app.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Fatal(err)
	}
	multiWriter := io.MultiWriter(os.Stdout, file)
	log.SetOutput(multiWriter)
	log.Printf("Log is ready")
	return file
}
