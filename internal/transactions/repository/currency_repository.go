package repository

import (
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm/clause"

	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateUpdateCurrencyRate(base string, target string, rate decimal.Decimal) error {
	currencyRate := models.CurrencyExchangeRate{
		CurrencyCode1: base,
		CurrencyCode2: target,
		Rate:          rate,
		LastUpdated:   time.Now(),
	}
	return db.DB.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "currency_code1"}, {Name: "currency_code2"}},
		DoUpdates: clause.AssignmentColumns([]string{"rate", "last_updated"}),
	}).Create(&currencyRate).Error
}
