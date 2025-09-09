package auth

import (
	"errors"
	"gorm.io/gorm"
	"moneef/internal/models"
)

func CheckEmailExist(email string) (bool, error) {
	user, err := GetUserByEmail(email)
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
	if err := CreateUser(user); err != nil {
		return err
	}
	return nil
}

func CheckUserCredentials(email, password string) (string, error) {
	user, err := CheckCredentialsMatch(email, password)
	if err != nil {
		return "", err
	}
	return user.Email, nil
}
