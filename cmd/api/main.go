package main

import (
	"fmt"
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

func run() error {
	log.Println("Connecting to the database")
	database, err := db.Connect()
	if err != nil {
		return fmt.Errorf("failed to connect to the database: %w", err)
	}
	log.Println("Loading config")
	configEnv := config.GetConfig()
	log.Println("Setting up logs")
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
		log.Printf("Failed to load icon lookup cache: %v", err)
	}
	mux := routes.SetupRoutes()
	log.Printf("Server running at http://localhost%s\n", configEnv.Port)
	return http.ListenAndServe(configEnv.Port, mux)
}
