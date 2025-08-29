package internal

import (
	"flag"
	"github.com/alexedwards/scs/v2"
	"github.com/joho/godotenv"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

type Config struct {
	Port         string
	JWTSecret    string
	JWT_PC_TOKEN string
}

var (
	config *Config
	once   sync.Once
)

func GetConfig() *Config {
	once.Do(func() {
		_ = godotenv.Load()
		config = &Config{
			Port:         getEnv("port", ":8000"),
			JWTSecret:    getEnv("jwt_secret", "my$up3rS3cr3tK3y!@2025#random1234567890"),
			JWT_PC_TOKEN: "eyJhbGciOiJIUzI1NiJ9.eyJNYW5nYSBTdG9yZSI6Ik1hbmdhU3RvcmU5MzIyMjIyMjIifQ.MxYlQRmIhWJkoWLDx2pwqWDup3rqkq_tWTPeHQwS_xY",
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
	manager.Cookie.Secure = true // Set to false for local dev if no HTTPS
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
