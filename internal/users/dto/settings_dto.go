package dto

type SettingsResponse struct {
	CurrencyCode          string `json:"currency_code"`
	Language              string `json:"language"`
	IsNotificationEnabled bool   `json:"is_notification_enabled"`
	IsDarkMode            bool   `json:"is_dark_mode"`
}

type UpdateSettingsRequest struct {
	CurrencyCode          *string `json:"currency_code,omitempty" validate:"omitempty,len=3"`
	Language              *string `json:"language,omitempty" validate:"omitempty,oneof=en ar"`
	IsNotificationEnabled *bool   `json:"is_notification_enabled,omitempty"`
	IsDarkMode            *bool   `json:"is_dark_mode,omitempty"`
}
