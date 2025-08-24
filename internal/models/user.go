package models

import (
	"gorm.io/gorm"
)

type User struct {
	gorm.Model
	Password     string       `gorm:"type:varchar(255);not null"`
	Email        string       `gorm:"type:varchar(255);not null;unique"`
	IsStaff      string       `gorm:"default:false"`
	isActive     string       `gorm:"default:true"`
	isSuperUser  string       `gorm:"default:false"`
	Profile      Profile      `gorm:"foreignKey:UserID"`
	UserSettings UserSettings `gorm:"foreignKey:UserID"`
}

type Profile struct {
	gorm.Model
	FirstName    string         `gorm:"type:varchar(255)"`
	LastName     string         `gorm:"type:varchar(255)"`
	UserID       uint           `gorm:"not null;"`
	Categories   *[]Category    `gorm:"foreignKey:ProfileID;"`
	Patterns     *[]Pattern     `gorm:"foreignKey:ProfileID;"`
	Transactions *[]Transaction `gorm:"foreignKey:ProfileID;"`
}

type UserSettings struct {
	gorm.Model
	UserID                uint   `gorm:"not null;"`
	Locale                string `gorm:"not null;"`
	IsNotificationEnabled bool   `gorm:"default:true"`
	IsDarkMode            bool   `gorm:"default:false"`
}
