package auth

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func ProfileByIdExist(id uint) (bool, error) {
	var count int64
	err := db.DB.Model(&models.Profile{}).Where("id = ?", id).Count(&count).Error
	return count > 0, err
}
