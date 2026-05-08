package repository

import (
	"gorm.io/gorm"
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

func GetUserByID(id uint) (*models.User, error) {
	var user models.User
	result := db.DB.Where("id = ?", id).First(&user)
	if result.Error != nil {
		return nil, result.Error
	}
	return &user, nil
}

func CreateUser(tx *gorm.DB, user *models.User) error {
	return tx.Create(user).Error
}

func CreateProfile(tx *gorm.DB, profile *models.Profile) error {
	return tx.Create(profile).Error
}

func CreateUserSettings(tx *gorm.DB, settings *models.UserSettings) error {
	return tx.Create(settings).Error
}
