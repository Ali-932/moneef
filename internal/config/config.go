package config

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
	Port               string
	ExchangeRateApiKey string
	JWTSecret          string
}

var (
	config *Config
	once   sync.Once
)

type defaultCurrencies struct {
	Code   string
	Symbol string
	Name   string
}

var Currencies = []defaultCurrencies{
	// Major Global Currencies
	{Code: "USD", Symbol: "$", Name: "US Dollar"},
	{Code: "EUR", Symbol: "€", Name: "Euro"},
	{Code: "GBP", Symbol: "£", Name: "British Pound Sterling"},
	{Code: "JPY", Symbol: "¥", Name: "Japanese Yen"},
	{Code: "CNY", Symbol: "¥", Name: "Chinese Yuan"},
	{Code: "CAD", Symbol: "C$", Name: "Canadian Dollar"},
	{Code: "AUD", Symbol: "A$", Name: "Australian Dollar"},
	{Code: "CHF", Symbol: "CHF", Name: "Swiss Franc"},
	{Code: "SEK", Symbol: "kr", Name: "Swedish Krona"},
	{Code: "NOK", Symbol: "kr", Name: "Norwegian Krone"},
	{Code: "DKK", Symbol: "kr", Name: "Danish Krone"},
	{Code: "INR", Symbol: "₹", Name: "Indian Rupee"},
	{Code: "KRW", Symbol: "₩", Name: "South Korean Won"},
	{Code: "SGD", Symbol: "S$", Name: "Singapore Dollar"},
	{Code: "HKD", Symbol: "HK$", Name: "Hong Kong Dollar"},
	{Code: "NZD", Symbol: "NZ$", Name: "New Zealand Dollar"},
	{Code: "MXN", Symbol: "$", Name: "Mexican Peso"},
	{Code: "BRL", Symbol: "R$", Name: "Brazilian Real"},
	{Code: "RUB", Symbol: "₽", Name: "Russian Ruble"},
	{Code: "ZAR", Symbol: "R", Name: "South African Rand"},

	// Middle Eastern Currencies
	{Code: "IQD", Symbol: "ع.د", Name: "Iraqi Dinar"},
	{Code: "SAR", Symbol: "﷼", Name: "Saudi Riyal"},
	{Code: "AED", Symbol: "د.إ", Name: "UAE Dirham"},
	{Code: "QAR", Symbol: "﷼", Name: "Qatari Riyal"},
	{Code: "KWD", Symbol: "د.ك", Name: "Kuwaiti Dinar"},
	{Code: "BHD", Symbol: ".د.ب", Name: "Bahraini Dinar"},
	{Code: "OMR", Symbol: "﷼", Name: "Omani Rial"},
	{Code: "JOD", Symbol: "د.ا", Name: "Jordanian Dinar"},
	{Code: "LBP", Symbol: "ل.ل", Name: "Lebanese Pound"},
	{Code: "EGP", Symbol: "£", Name: "Egyptian Pound"},
	{Code: "IRR", Symbol: "﷼", Name: "Iranian Rial"},
	{Code: "TRY", Symbol: "₺", Name: "Turkish Lira"},
}

func GetConfig() *Config {
	once.Do(func() {
		_ = godotenv.Load()
		config = &Config{
			Port:               getEnv("port", ":8000"),
			ExchangeRateApiKey: getEnv("exchange_rate_api_key", "f5b4aaa9448c0f9a060ca1ef"),
			JWTSecret:          getEnv("jwt_secret", "my$up3rS3cr3tK3y!@2025#random1234567890"),
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
