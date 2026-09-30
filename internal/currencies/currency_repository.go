package currencies

import (
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm/clause"

	"moneef/internal/db"
	"moneef/internal/models"
)

func listCurrencies() ([]models.Currency, error) {
	var list []models.Currency
	err := db.DB.Order("code ASC").Find(&list).Error
	return list, err
}

func GetExchangeRates(baseCurrency string) ([]models.CurrencyExchangeRate, error) {
	var rates []models.CurrencyExchangeRate
	err := db.DB.Where("currency_code2 = ?", baseCurrency).Order("currency_code1").Find(&rates).Error
	return rates, err
}

// GetUsdRates returns the USD→X rows: how many X one USD buys.
func GetUsdRates() ([]models.CurrencyExchangeRate, error) {
	var rates []models.CurrencyExchangeRate
	err := db.DB.Where("currency_code1 = 'USD'").Find(&rates).Error
	return rates, err
}

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
