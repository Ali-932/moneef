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
	FirstName    string         `gorm:"type:varchar(255)"`
	LastName     string         `gorm:"type:varchar(255)"`
	UserID       uint           `gorm:"not null;"`
	Categories   *[]Category    `gorm:"foreignKey:ProfileID;"`
	Patterns     *[]Pattern     `gorm:"foreignKey:ProfileID;"`
	Transactions *[]Transaction `gorm:"foreignKey:ProfileID;references:ID;constraint:OnDelete:CASCADE;"`
}

type UserSettings struct {
	gorm.Model
	UserID                uint      `gorm:"not null;"`
	CurrencyCode          string    `gorm:"type:char(3);not null;index; default:'USD'"`
	Currency              *Currency `gorm:"foreignKey:CurrencyCode;references:Code"`
	Language              string    `gorm:"type:varchar(10);not null;default:'en';check:language IN ('en','ar')"`
	IsNotificationEnabled bool      `gorm:"default:true"`
	IsDarkMode            bool      `gorm:"default:false"`
}
