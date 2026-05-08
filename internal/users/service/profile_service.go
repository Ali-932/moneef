package service

import (
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/users/dto"
	"moneef/internal/users/repository"
)

func GetProfile(profileID uint) (*models.Profile, error) {
	return repository.GetProfileByID(profileID)
}

func UpdateProfile(profileID uint, req dto.UpdateProfileRequest) error {
	updates := map[string]interface{}{
		"first_name": req.FirstName,
		"last_name":  req.LastName,
	}
	return repository.UpdateProfile(db.DB, profileID, updates)
}

func GetSettings(userID uint) (*models.UserSettings, error) {
	return repository.GetUserSettingsByUserID(userID)
}

func UpdateSettings(userID uint, req dto.UpdateSettingsRequest) error {
	updates := make(map[string]interface{})
	if req.CurrencyCode != nil {
		updates["currency_code"] = *req.CurrencyCode
	}
	if req.Language != nil {
		updates["language"] = *req.Language
	}
	if req.IsNotificationEnabled != nil {
		updates["is_notification_enabled"] = *req.IsNotificationEnabled
	}
	if req.IsDarkMode != nil {
		updates["is_dark_mode"] = *req.IsDarkMode
	}
	if len(updates) == 0 {
		return nil
	}
	return repository.UpdateUserSettings(db.DB, userID, updates)
}
