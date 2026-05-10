package models

import (
	"gorm.io/gorm"
	"time"
)

type User struct {
	gorm.Model
	Password     string       `gorm:"type:varchar(255);not null"`
	Email        string       `gorm:"type:varchar(255);not null;unique"`
	IsStaff      bool         `gorm:"default:false"`
	IsActive     bool         `gorm:"default:true"`
	IsSuperUser  bool         `gorm:"default:false"`
	Profile      Profile      `gorm:"foreignKey:UserID"`
	UserSettings UserSettings `gorm:"foreignKey:UserID"`
	Birthday     *time.Time
}

type Profile struct {
	gorm.Model
	FirstName    string         `gorm:"type:varchar(255)" json:"first_name"`
	LastName     string         `gorm:"type:varchar(255)" json:"last_name"`
	UserID       uint           `gorm:"not null;" json:"user_id"`
	Categories   *[]Category    `gorm:"foreignKey:ProfileID;" json:"categories,omitempty"`
	Patterns     *[]Pattern     `gorm:"foreignKey:ProfileID;" json:"patterns,omitempty"`
	Transactions *[]Transaction `gorm:"foreignKey:ProfileID;references:ID;constraint:OnDelete:CASCADE;" json:"transactions,omitempty"`
}

type UserSettings struct {
	gorm.Model
	UserID                uint      `gorm:"not null;" json:"user_id"`
	CurrencyCode          string    `gorm:"type:char(3);not null;index; default:'USD'" json:"currency_code"`
	Currency              *Currency `gorm:"foreignKey:CurrencyCode;references:Code" json:"currency,omitempty"`
	Language              string    `gorm:"type:varchar(10);not null;default:'en';check:language IN ('en','ar')" json:"language"`
	IsNotificationEnabled bool      `gorm:"default:true" json:"is_notification_enabled"`
	IsDarkMode            bool      `gorm:"default:false" json:"is_dark_mode"`
}
