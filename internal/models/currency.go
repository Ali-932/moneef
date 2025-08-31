package models

import "gorm.io/gorm"

type Currency struct {
	Code   string `gorm:"primaryKey;type:char(3)"` // USD, EUR, etc.
	Name   string `gorm:"type:varchar(100)"`       // US Dollar, Euro
	Symbol string `gorm:"type:varchar(10)"`        // $, €, £
}

type CurrencyExchangeRate struct {
	gorm.Model
	CurrencyCode1 string  `gorm:"type:char(3);not null;index"` // e.g., USD
	CurrencyCode2 string  `gorm:"type:char(3);not null;index"` // e.g., EUR
	Rate          float64 `gorm:"type:decimal(19,6);not null"` // e.g., 0.85
}
