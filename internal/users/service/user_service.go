package service

import (
	"errors"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/internal/users/repository"
)

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

func CreateUserService(user *models.User) error {
	if err := repository.CreateUser(user); err != nil {
		return err
	}
	return nil
}
