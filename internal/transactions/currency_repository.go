package transactions

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateUpdateCurrencyRate(base string, target string, rate float64) error {
	var count int64
	err := db.DB.Model(&models.CurrencyExchangeRate{}).
		Where("currency_code1 = ? AND currency_code2 = ?", base, target).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count >= 1 {
		err = db.DB.Model(&models.CurrencyExchangeRate{}).
			Where("currency_code1 = ? and currency_code2 = ?", base, target).
			Update("Rate", rate).Error

	} else {
		currencyRateObject := models.CurrencyExchangeRate{CurrencyCode1: base, CurrencyCode2: target, Rate: rate}
		err = db.DB.Create(&currencyRateObject).Error

	}
	if err != nil {
		return err
	}
	return nil

}
