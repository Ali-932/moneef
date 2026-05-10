package currencies

import "moneef/internal/models"

func ListCurrencies() ([]models.Currency, error) {
	return listCurrencies()
}
