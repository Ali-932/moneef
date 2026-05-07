package dto

import "time"

type RegisterRequest struct {
	Email    string     `json:"email" validate:"required,email"`
	Password string     `json:"password" validate:"required"`
	Birthday *time.Time `json:"birthday"`
}
