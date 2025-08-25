package utils

import (
	"errors"
	"github.com/golang-jwt/jwt/v5"
	"moneef/internal"
	"time"
)

func GenerateJWT(username string) (string, error) {
	config := internal.GetConfig()
	var JwtKey = []byte(config.JWTSecret)
	claims := jwt.MapClaims{
		"username": username,
		"exp":      time.Now().Add(time.Hour * 672).Unix(), // expires in a month
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	SignedToken, err := token.SignedString(JwtKey)
	if err != nil {
		return "", err
	}
	return SignedToken, nil
}

func ValidateJWT(tokenString string) (jwt.MapClaims, error) {
	config := internal.GetConfig()
	secret := []byte(config.JWTSecret)
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return secret, nil
	})

	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		return claims, nil
	}
	return nil, errors.New("invalid token")
}
