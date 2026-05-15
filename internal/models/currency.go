package models

import (
	"time"

	"github.com/shopspring/decimal"
)

type Currency struct {
	Code   string `gorm:"primaryKey;type:char(3)" json:"code"`
	Name   string `gorm:"type:varchar(100)" json:"name"`
	Symbol string `gorm:"type:varchar(10)" json:"symbol"`
}

type CurrencyExchangeRate struct {
	ID            uint            `gorm:"primaryKey" json:"id"`
	CreatedAt     time.Time       `json:"created_at"`
	UpdatedAt     time.Time       `json:"updated_at"`
	CurrencyCode1 string          `gorm:"type:char(3);not null;uniqueIndex:idx_currency_pair" json:"currency_code_1"`
	CurrencyCode2 string          `gorm:"type:char(3);not null;uniqueIndex:idx_currency_pair" json:"currency_code_2"`
	Rate          decimal.Decimal `gorm:"type:decimal(19,6);not null" json:"rate"`
	LastUpdated   time.Time       `json:"last_updated"`
}
