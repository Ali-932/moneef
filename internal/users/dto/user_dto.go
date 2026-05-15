package dto

import "time"

type RegisterRequest struct {
	Email     string     `json:"email" validate:"required,email"`
	Password  string     `json:"password" validate:"required"`
	FirstName string     `json:"first_name" validate:"required"`
	LastName  string     `json:"last_name" validate:"required"`
	Birthday  *time.Time `json:"birthday"`
}

type SetupRequest struct {
	FirstName          string `json:"first_name" validate:"required"`
	LastName           string `json:"last_name" validate:"required"`
	CurrencyCode       string `json:"currency_code" validate:"required,len=3"`
	Language           string `json:"language,omitempty"`
	ExchangeRateApiKey string `json:"exchange_rate_api_key,omitempty"`
}
