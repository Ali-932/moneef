package service

import (
	"fmt"

	"gorm.io/gorm"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/users/dto"
	"moneef/internal/users/repository"
)

func GetUserByID(id uint) (*models.User, error) {
	return repository.GetUserByID(id)
}

func Setup(req dto.SetupRequest) (*models.Profile, *models.UserSettings, error) {
	language := req.Language
	if language == "" {
		language = "en"
	}

	var resultProfile *models.Profile
	var resultSettings *models.UserSettings

	err := db.DB.Transaction(func(tx *gorm.DB) error {
		user := &models.User{
			IsActive: true,
		}
		if err := repository.CreateUser(tx, user); err != nil {
			return fmt.Errorf("failed to create user: %w", err)
		}

		profile := &models.Profile{
			UserID:    user.ID,
			FirstName: req.FirstName,
			LastName:  req.LastName,
		}
		if err := repository.CreateProfile(tx, profile); err != nil {
			return fmt.Errorf("failed to create profile: %w", err)
		}

		settings := &models.UserSettings{
			UserID:       user.ID,
			CurrencyCode: req.CurrencyCode,
			Language:     language,
		}
		if err := repository.CreateUserSettings(tx, settings); err != nil {
			return fmt.Errorf("failed to create settings: %w", err)
		}

		resultProfile = profile
		resultSettings = settings
		return nil
	})
	if err != nil {
		return nil, nil, err
	}

	return resultProfile, resultSettings, nil
}
