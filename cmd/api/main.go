package main

import (
	"github.com/alexedwards/scs/v2"
	"log"
	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/routes"
	"net/http"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("Application failed to start: %v", err)
	}

}

var SessionManager *scs.SessionManager

func run() error {
	log.Println("Connecting to the database")
	database, err := db.Connect()
	log.Println("Loading Config")
	configEnv := config.GetConfig()
	if err != nil {
		log.Fatal("can ot connect to the database")
	}
	log.Println("Setting up sessions")
	SessionManager = config.SetUpSessions()
	log.Printf("Setting up logs")
	logFile := config.SetUpLogs()
	defer func() {
		if err := logFile.Close(); err != nil {
			log.Println("Error closing log file:", err)
		}
	}()
	err = db.MigrateModels(database)
	if err != nil {
		return err
	}
	log.Println("Done migrations")
	if err := iconlookup.LoadCache(database); err != nil {
		log.Printf("⚠️ Failed to load icon lookup cache: %v", err)
	}
	mux := routes.SetupRoutes()
	wrappedMux := SessionManager.LoadAndSave(mux)
	log.Printf("Server running at http://localhost%s\n", configEnv.Port)
	return http.ListenAndServe(configEnv.Port, wrappedMux)
}
