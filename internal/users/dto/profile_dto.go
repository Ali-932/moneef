package dto

import "time"

type ProfileResponse struct {
	ID        uint       `json:"id"`
	FirstName string     `json:"first_name"`
	LastName  string     `json:"last_name"`
	Email     string     `json:"email"`
	Birthday  *time.Time `json:"birthday,omitempty"`
}

type UpdateProfileRequest struct {
	FirstName string `json:"first_name" validate:"required"`
	LastName  string `json:"last_name" validate:"required"`
}
