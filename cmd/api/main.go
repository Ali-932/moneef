package main

import (
	"github.com/alexedwards/scs/v2"
	"log"
	"moneef/internal"
	"moneef/internal/db"
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
	config := internal.GetConfig()
	if err != nil {
		log.Fatal("can ot connect to the database")
	}
	log.Println("Setting up sessions")
	SessionManager = internal.SetUpSessions()
	log.Printf("Setting up logs")
	logFile := internal.SetUpLogs()
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
	log.Println("Seeding essential data")
	if err := db.Seed(database); err != nil {
		return err
	}
	mux := routes.SetupRoutes()
	wrappedMux := SessionManager.LoadAndSave(mux)
	log.Printf("Server running at http://localhost%s\n", config.Port)
	return http.ListenAndServe(config.Port, wrappedMux)
}
