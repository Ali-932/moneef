package db

import (
	"fmt"
	stdlog "log"
	"os"
	"path/filepath"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"moneef/internal/config"
)

var DB *gorm.DB

func Connect() (*gorm.DB, error) {

	logCfg := logger.New(
		stdlog.New(os.Stdout, "[GORM] ", stdlog.LstdFlags),
		logger.Config{
			SlowThreshold:        500 * time.Millisecond,
			LogLevel:             logger.Error,
			ParameterizedQueries: true,
			Colorful:             true,
		},
	)

	dbPath := config.GetConfig().DBPath
	stdlog.Printf("connecting to database: %s", dbPath)

	if err := os.MkdirAll(filepath.Dir(dbPath), 0755); err != nil {
		return nil, fmt.Errorf("cannot create database directory: %w", err)
	}

	db, err := gorm.Open(sqlite.Open(dbPath+"?_foreign_keys=on&_journal_mode=WAL"), &gorm.Config{Logger: logCfg, DisableForeignKeyConstraintWhenMigrating: false})
	if err != nil {
		return nil, fmt.Errorf("cannot connect to the database %w", err)
	}

	DB = db
	return db, nil
}
