package db

import (
	"fmt"
	stdlog "log"
	"os"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
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

	db, err := gorm.Open(sqlite.Open("db.sqlite"), &gorm.Config{Logger: logCfg})
	if err != nil {
		return nil, fmt.Errorf("connot connect to the database %w", err)
	}

	DB = db
	return db, nil
}
