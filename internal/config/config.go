package config

import (
	"log"
	"os"
	"path/filepath"
	"sync"
)

type Config struct {
	DBPath string
}

var (
	config *Config
	once   sync.Once
)

func GetConfig() *Config {
	once.Do(func() {
		dbPath := getEnv("db_path", "")
		if dbPath == "" {
			configDir, err := os.UserConfigDir()
			if err != nil {
				log.Fatal("cannot determine config directory: ", err)
			}
			dbPath = filepath.Join(configDir, "moneef", "db.sqlite")
		}

		config = &Config{
			DBPath: dbPath,
		}
	})

	return config
}

func getEnv(key, defaultValue string) string {
	if value, exist := os.LookupEnv(key); exist {
		return value
	}

	return defaultValue
}
