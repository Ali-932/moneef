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
	"USD": {time.Saturday, time.Sunday}, // United States Dollar
	"EUR": {time.Saturday, time.Sunday}, // Euro (Eurozone)
	"GBP": {time.Saturday, time.Sunday}, // British Pound
	"JPY": {time.Saturday, time.Sunday}, // Japanese Yen
	"CNY": {time.Saturday, time.Sunday}, // Chinese Yuan
	"CAD": {time.Saturday, time.Sunday}, // Canadian Dollar
	"AUD": {time.Saturday, time.Sunday}, // Australian Dollar
	"CHF": {time.Saturday, time.Sunday}, // Swiss Franc
	"SEK": {time.Saturday, time.Sunday}, // Swedish Krona
	"NOK": {time.Saturday, time.Sunday}, // Norwegian Krone
	"DKK": {time.Saturday, time.Sunday}, // Danish Krone
	"INR": {time.Saturday, time.Sunday}, // Indian Rupee
	"KRW": {time.Saturday, time.Sunday}, // South Korean Won
	"SGD": {time.Saturday, time.Sunday}, // Singapore Dollar
	"HKD": {time.Saturday, time.Sunday}, // Hong Kong Dollar
	"NZD": {time.Saturday, time.Sunday}, // New Zealand Dollar
	"MXN": {time.Saturday, time.Sunday}, // Mexican Peso
	"BRL": {time.Saturday, time.Sunday}, // Brazilian Real
	"RUB": {time.Saturday, time.Sunday}, // Russian Ruble
	"ZAR": {time.Saturday, time.Sunday}, // South African Rand
	"LBP": {time.Saturday, time.Sunday}, // Lebanese Pound
	"TRY": {time.Saturday, time.Sunday}, // Turkish Lira

	// Friday-Saturday Weekend (Islamic Countries)
	"SAR": {time.Friday, time.Saturday}, // Saudi Riyal
	"AED": {time.Friday, time.Saturday}, // UAE Dirham
	"QAR": {time.Friday, time.Saturday}, // Qatari Riyal
	"KWD": {time.Friday, time.Saturday}, // Kuwaiti Dinar
	"BHD": {time.Friday, time.Saturday}, // Bahraini Dinar
	"OMR": {time.Friday, time.Saturday}, // Omani Rial
	"JOD": {time.Friday, time.Saturday}, // Jordanian Dinar
	"EGP": {time.Friday, time.Saturday}, // Egyptian Pound
	"IQD": {time.Friday, time.Saturday}, // Iraqi Dinar

	// Thursday-Friday Weekend
	"IRR": {time.Thursday, time.Friday}, // Iranian Rial
}
