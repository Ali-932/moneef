package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateTransaction(transaction *models.Transaction) error {
	return db.DB.Create(transaction).Error
}
