package repository

import (
	"gorm.io/gorm"
	"moneef/internal/db"
	"moneef/internal/models"
)

func ProfileByIdExist(id uint) (bool, error) {
	var count int64
	err := db.DB.Model(&models.Profile{}).Where("id = ?", id).Count(&count).Error
	return count > 0, err
}

func GetProfileByID(id uint) (*models.Profile, error) {
	var profile models.Profile
	err := db.DB.Where("id = ?", id).First(&profile).Error
	if err != nil {
		return nil, err
	}
	return &profile, nil
}

func UpdateProfile(tx *gorm.DB, id uint, updates map[string]interface{}) error {
	result := tx.Model(&models.Profile{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func GetUserSettingsByUserID(userID uint) (*models.UserSettings, error) {
	var settings models.UserSettings
	err := db.DB.Where("user_id = ?", userID).First(&settings).Error
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

func UpdateUserSettings(tx *gorm.DB, userID uint, updates map[string]interface{}) error {
	result := tx.Model(&models.UserSettings{}).Where("user_id = ?", userID).Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
