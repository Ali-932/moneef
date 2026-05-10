package models

import "gorm.io/gorm"

type Currency struct {
	Code   string `gorm:"primaryKey;type:char(3)" json:"Code"` // USD, EUR, etc.
	Name   string `gorm:"type:varchar(100)" json:"Name"`       // US Dollar, Euro
	Symbol string `gorm:"type:varchar(10)" json:"Symbol"`        // $, €, £
}

type CurrencyExchangeRate struct {
	gorm.Model
	CurrencyCode1 string  `gorm:"type:char(3);not null;index" json:"currency_code_1"`
	CurrencyCode2 string  `gorm:"type:char(3);not null;index" json:"currency_code_2"`
	Rate          float64 `gorm:"type:decimal(19,6);not null" json:"rate"`
}
