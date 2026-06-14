//go:build !android

package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/routes"
)

func main() {
	slog.Info("connecting to database")
	database, err := db.Connect()
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}

	configEnv := config.GetConfig()

	logFile := config.SetUpLogs()
	defer func() {
		if err := logFile.Close(); err != nil {
			slog.Error("error closing log file", "error", err)
		}
	}()

	if err := db.MigrateModels(database); err != nil {
		slog.Error("migration failed", "error", err)
		os.Exit(1)
	}
	slog.Info("migrations complete")

	if err := iconlookup.LoadCache(database); err != nil {
		slog.Error("failed to load icon lookup cache", "error", err)
	}

	mux := routes.SetupRoutes()

	srv := &http.Server{
		Addr:         configEnv.Port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		slog.Info("server starting", "port", configEnv.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	slog.Info("shutting down server")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server forced shutdown", "error", err)
	}
	slog.Info("server stopped")
}
