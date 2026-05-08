package service

import (
	"errors"
	"gorm.io/gorm"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/users/dto"
	"moneef/internal/users/repository"
)

func GetUserByID(id uint) (*models.User, error) {
	return repository.GetUserByID(id)
}

func CheckEmailExist(email string) (bool, error) {
	user, err := repository.GetUserByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, nil
		}
		return false, err
	}
	if user == nil {
		return false, nil
	}
	return true, nil
}

func RegisterUser(req dto.RegisterRequest, hashedPassword string) error {
	return db.DB.Transaction(func(tx *gorm.DB) error {
		user := &models.User{
			Email:    req.Email,
			Password: hashedPassword,
			Birthday: req.Birthday,
		}
		if err := repository.CreateUser(tx, user); err != nil {
			return err
		}

		profile := &models.Profile{
			FirstName: req.FirstName,
			LastName:  req.LastName,
			UserID:    user.ID,
		}
		if err := repository.CreateProfile(tx, profile); err != nil {
			return err
		}

		settings := &models.UserSettings{
			UserID:                user.ID,
			CurrencyCode:          "USD",
			Language:              "en",
			IsNotificationEnabled: true,
			IsDarkMode:            false,
		}
		if err := repository.CreateUserSettings(tx, settings); err != nil {
			return err
		}

		return nil
	})
}
