package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateTransactionRecurrent(tpl *models.RecurrenceTemplate) (uint, error) {
	if err := db.DB.Create(tpl).Error; err != nil {
		return 0, err
	}
	return tpl.ID, nil
}
