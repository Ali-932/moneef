package config

import "time"

const (
	AmountRounding                        int32 = 2
	CategoriesOthersThreshold                   = 7
	AnalysisMaxRecurringTransactionsCHart       = 7
)

type defaultCurrencies struct {
	Code   string
	Symbol string
	Name   string
}

type Country struct {
	Code         string
	Name         string
	CurrencyCode string
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

var Countries = []Country{
	{Code: "US", Name: "United States", CurrencyCode: "USD"},
	{Code: "DE", Name: "Germany", CurrencyCode: "EUR"}, // Representative Eurozone country
	{Code: "GB", Name: "United Kingdom", CurrencyCode: "GBP"},
	{Code: "JP", Name: "Japan", CurrencyCode: "JPY"},
	{Code: "CN", Name: "China", CurrencyCode: "CNY"},
	{Code: "CA", Name: "Canada", CurrencyCode: "CAD"},
	{Code: "AU", Name: "Australia", CurrencyCode: "AUD"},
	{Code: "CH", Name: "Switzerland", CurrencyCode: "CHF"},
	{Code: "SE", Name: "Sweden", CurrencyCode: "SEK"},
	{Code: "NO", Name: "Norway", CurrencyCode: "NOK"},
	{Code: "DK", Name: "Denmark", CurrencyCode: "DKK"},
	{Code: "IN", Name: "India", CurrencyCode: "INR"},
	{Code: "KR", Name: "South Korea", CurrencyCode: "KRW"},
	{Code: "SG", Name: "Singapore", CurrencyCode: "SGD"},
	{Code: "HK", Name: "Hong Kong", CurrencyCode: "HKD"},
	{Code: "NZ", Name: "New Zealand", CurrencyCode: "NZD"},
	{Code: "MX", Name: "Mexico", CurrencyCode: "MXN"},
	{Code: "BR", Name: "Brazil", CurrencyCode: "BRL"},
	{Code: "RU", Name: "Russia", CurrencyCode: "RUB"},
	{Code: "ZA", Name: "South Africa", CurrencyCode: "ZAR"},

	// Middle Eastern Countries
	{Code: "IQ", Name: "Iraq", CurrencyCode: "IQD"},
	{Code: "SA", Name: "Saudi Arabia", CurrencyCode: "SAR"},
	{Code: "AE", Name: "United Arab Emirates", CurrencyCode: "AED"},
	{Code: "QA", Name: "Qatar", CurrencyCode: "QAR"},
	{Code: "KW", Name: "Kuwait", CurrencyCode: "KWD"},
	{Code: "BH", Name: "Bahrain", CurrencyCode: "BHD"},
	{Code: "OM", Name: "Oman", CurrencyCode: "OMR"},
	{Code: "JO", Name: "Jordan", CurrencyCode: "JOD"},
	{Code: "LB", Name: "Lebanon", CurrencyCode: "LBP"},
	{Code: "EG", Name: "Egypt", CurrencyCode: "EGP"},
	{Code: "IR", Name: "Iran", CurrencyCode: "IRR"},
	{Code: "TR", Name: "Turkey", CurrencyCode: "TRY"},
}

type Weekday int

var WeekendPatterns = map[string][]time.Weekday{
	// Saturday-Sunday Weekend (Most Common)
	"US": {time.Saturday, time.Sunday}, // United States
	"DE": {time.Saturday, time.Sunday}, // Germany (Eurozone representative)
	"GB": {time.Saturday, time.Sunday}, // United Kingdom
	"JP": {time.Saturday, time.Sunday}, // Japan
	"CN": {time.Saturday, time.Sunday}, // China
	"CA": {time.Saturday, time.Sunday}, // Canada
	"AU": {time.Saturday, time.Sunday}, // Australia
	"CH": {time.Saturday, time.Sunday}, // Switzerland
	"SE": {time.Saturday, time.Sunday}, // Sweden
	"NO": {time.Saturday, time.Sunday}, // Norway
	"DK": {time.Saturday, time.Sunday}, // Denmark
	"IN": {time.Saturday, time.Sunday}, // India
	"KR": {time.Saturday, time.Sunday}, // South Korea
	"SG": {time.Saturday, time.Sunday}, // Singapore
	"HK": {time.Saturday, time.Sunday}, // Hong Kong
	"NZ": {time.Saturday, time.Sunday}, // New Zealand
	"MX": {time.Saturday, time.Sunday}, // Mexico
	"BR": {time.Saturday, time.Sunday}, // Brazil
	"RU": {time.Saturday, time.Sunday}, // Russia
	"ZA": {time.Saturday, time.Sunday}, // South Africa
	"LB": {time.Saturday, time.Sunday}, // Lebanon
	"TR": {time.Saturday, time.Sunday}, // Turkey

	// Friday-Saturday Weekend (Islamic Countries)
	"SA": {time.Friday, time.Saturday}, // Saudi Arabia
	"AE": {time.Friday, time.Saturday}, // UAE
	"QA": {time.Friday, time.Saturday}, // Qatar
	"KW": {time.Friday, time.Saturday}, // Kuwait
	"BH": {time.Friday, time.Saturday}, // Bahrain
	"OM": {time.Friday, time.Saturday}, // Oman
	"JO": {time.Friday, time.Saturday}, // Jordan
	"EG": {time.Friday, time.Saturday}, // Egypt
	"IQ": {time.Friday, time.Saturday}, // Iraq

	// Thursday-Friday Weekend
	"IR": {time.Thursday, time.Friday}, // Iran
}
