package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func GetUserByEmail(email string) (*models.User, error) {
	var user models.User
	result := db.DB.Where("email = ?", email).First(&user)
	if result.Error != nil {
		return nil, result.Error
	}
	return &user, nil
}

func CreateUser(user *models.User) error {
	return db.DB.Create(user).Error
}
