package config

import (
	"log"
	"os"
	"path/filepath"
	"sync"

	"github.com/joho/godotenv"
)

type Config struct {
	Port               string
	ExchangeRateApiKey string
	DBPath             string
}

var (
	config *Config
	once   sync.Once
)

func GetConfig() *Config {
	once.Do(func() {
		_ = godotenv.Load()
		dbPath := getEnv("db_path", "")
		if dbPath == "" {
			configDir, err := os.UserConfigDir()
			if err != nil {
				log.Fatal("cannot determine config directory: ", err)
			}
			dbPath = filepath.Join(configDir, "moneef", "db.sqlite")
		}

		config = &Config{
			Port:               getEnv("port", ":8000"),
			ExchangeRateApiKey: getEnv("exchange_rate_api_key", ""),
			DBPath:             dbPath,
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


