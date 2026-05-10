package config

import (
	"flag"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/alexedwards/scs/v2"
	"github.com/joho/godotenv"
)

type Config struct {
	Port               string
	ExchangeRateApiKey string
	JWTSecret          string
	DBPath             string
}

var (
	config *Config
	once   sync.Once
)

func GetConfig() *Config {
	once.Do(func() {
		_ = godotenv.Load()
		dbPath := getEnv("db_path", "/home/james/GolandProjects/moneef-backend/db.sqlite")
		if dbPath == "" {
			configDir, err := os.UserConfigDir()
			if err != nil {
				configDir = "."
			}
			dbPath = configDir + "/moneef/db.sqlite"
		}

		config = &Config{
			Port:               getEnv("port", ":8000"),
			ExchangeRateApiKey: getEnv("exchange_rate_api_key", "f5b4aaa9448c0f9a060ca1ef"),
			JWTSecret:          getEnv("jwt_secret", "my$up3rS3cr3tK3y!@2025#random1234567890"),
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

func SetUpSessions() *scs.SessionManager { // Exported now
	manager := scs.New()
	manager.Lifetime = 24 * time.Hour
	manager.Cookie.Name = "sessionid"
	manager.Cookie.HttpOnly = true
	manager.Cookie.Secure = false // Set to false for local dev if no HTTPS
	manager.Cookie.SameSite = http.SameSiteStrictMode
	return manager
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
