package dto

import "time"

type RegisterRequest struct {
	Email     string     `json:"email" validate:"required,email"`
	Password  string     `json:"password" validate:"required"`
	FirstName string     `json:"first_name" validate:"required"`
	LastName  string     `json:"last_name" validate:"required"`
	Birthday  *time.Time `json:"birthday"`
}
