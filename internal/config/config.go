package config

import (
	"flag"
	"io"
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
