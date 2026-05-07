package service

import (
	"moneef/internal/auth/repository"
)

func CheckUserCredentials(email, password string) (string, error) {
	user, err := repository.CheckCredentialsMatch(email, password)
	if err != nil {
		return "", err
	}
	return user.Email, nil
}
