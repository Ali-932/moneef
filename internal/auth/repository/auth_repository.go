package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/utils"
)

func GetUserByEmail(email string) (*models.User, error) {
	var user models.User
	result := db.DB.Where("email = ?", email).First(&user)
	if result.Error != nil {
		return nil, result.Error
	}
	return &user, nil
}

func CheckCredentialsMatch(email, password string) (*models.User, error) {
	user, err := GetUserByEmail(email)
	if err != nil {
		return nil, err
	}
	err = utils.CompareHashedPassword(user.Password, password)
	if err != nil {
		return nil, err
	}
	return user, nil
}
