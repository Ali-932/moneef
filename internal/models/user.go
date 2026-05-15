package models

import (
	"time"
)

type User struct {
	ID           uint          `gorm:"primaryKey" json:"id"`
	CreatedAt    time.Time     `json:"created_at"`
	UpdatedAt    time.Time     `json:"updated_at"`
	Email        string        `gorm:"type:varchar(255);unique" json:"email,omitempty"`
	Password     string        `gorm:"type:varchar(255)" json:"-"`
	IsStaff      bool          `gorm:"default:false" json:"-"`
	IsActive     bool          `gorm:"default:true" json:"is_active,omitempty"`
	IsSuperUser  bool          `gorm:"default:false" json:"-"`
	Profile      *Profile      `gorm:"foreignKey:UserID" json:"profile,omitempty"`
	UserSettings *UserSettings `gorm:"foreignKey:UserID" json:"settings,omitempty"`
	Birthday     *time.Time    `json:"birthday,omitempty"`
}

type Profile struct {
	ID           uint           `gorm:"primaryKey" json:"id"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	FirstName    string         `gorm:"type:varchar(255)" json:"first_name"`
	LastName     string         `gorm:"type:varchar(255)" json:"last_name"`
	UserID       uint           `gorm:"not null;index;constraint:OnDelete:CASCADE" json:"user_id"`
	Categories   *[]Category    `gorm:"foreignKey:ProfileID;" json:"categories,omitempty"`
	Patterns     *[]Pattern     `gorm:"foreignKey:ProfileID;" json:"patterns,omitempty"`
	Transactions *[]Transaction `gorm:"foreignKey:ProfileID;references:ID;constraint:OnDelete:CASCADE;" json:"transactions,omitempty"`
	User         *User          `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
}

type UserSettings struct {
	ID                    uint      `gorm:"primaryKey" json:"id"`
	CreatedAt             time.Time `json:"created_at"`
	UpdatedAt             time.Time `json:"updated_at"`
	UserID                uint      `gorm:"not null;index;constraint:OnDelete:CASCADE" json:"user_id"`
	CurrencyCode          string    `gorm:"type:char(3);not null;default:'USD'" json:"currency_code"`
	Currency              *Currency `gorm:"foreignKey:CurrencyCode;references:Code" json:"currency,omitempty"`
	Language              string    `gorm:"type:varchar(10);not null;default:'en'" json:"language"`
	IsNotificationEnabled bool      `gorm:"default:true" json:"is_notification_enabled"`
	IsDarkMode            bool      `gorm:"default:false" json:"is_dark_mode"`
	ExchangeRateApiKey    string    `gorm:"type:varchar(255);default:''" json:"exchange_rate_api_key"`
	User                  *User     `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
}
