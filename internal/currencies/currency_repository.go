package currencies

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func listCurrencies() ([]models.Currency, error) {
	var list []models.Currency
	err := db.DB.Order("code ASC").Find(&list).Error
	return list, err
}
