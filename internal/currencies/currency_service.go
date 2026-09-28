package currencies

import (
	"gorm.io/gorm"

	"moneef/internal/config"
	"moneef/internal/models"
)

func ListCurrencies() ([]models.Currency, error) {
	return listCurrencies()
}

// SeedCurrencies inserts the master currency list (config.Currencies) into the
// currencies table. Idempotent: existing codes are skipped.
func SeedCurrencies(database *gorm.DB) error {
	for _, d := range config.Currencies {
		var count int64
		if err := database.Model(&models.Currency{}).
			Where("code = ?", d.Code).
			Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			continue
		}
		cur := models.Currency{
			Code:   d.Code,
			Symbol: d.Symbol,
			Name:   d.Name,
		}
		if err := database.Create(&cur).Error; err != nil {
			return err
		}
	}
	return nil
}
