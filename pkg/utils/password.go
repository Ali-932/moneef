package utils

import "golang.org/x/crypto/bcrypt"

func HashPassword(password string) ([]byte, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	return hashedPassword, err
}

func CompareHashedPassword(hashedPassword, loginPassword string) error {
	err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(loginPassword))
	if err != nil {
		return err
	}
	return nil
}
