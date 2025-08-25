package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/utils"
)

func GetUserByUsername(username string) (*models.User, error) {
	var user models.User
	result := db.DB.Where("username = ?", username).First(&user)
	if result.Error != nil {
		return nil, result.Error
	}
	return &user, nil
}

func CheckCredentialsMatch(username, password string) (*models.User, error) {
	user, err := GetUserByUsername(username)
	if err != nil {
		return nil, err
	}
	err = utils.CompareHashedPassword(user.Password, password)
	if err != nil {
		return nil, err
	}
	return user, nil
}
