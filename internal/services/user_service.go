package services

import (
	"errors"
	"gorm.io/gorm"
	"moneef/internal/repository"
)

func CheckUsernameExist(username string) (bool, error) {
	user, err := repository.GetUserByUsername(username)
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

func CheckUserCredentials(username, password string) (string, error) {
	user, err := repository.CheckCredentialsMatch(username, password)
	if err != nil {
		return "", err
	}
	return user.Email, nil
}
