package models

import "gorm.io/gorm"

type IconLookup struct {
	gorm.Model
	Keyword string `gorm:"type:varchar(255);not null;uniqueIndex"`
	Icon    string `gorm:"type:varchar(255);not null"`
	Color   string `gorm:"type:varchar(255);not null"`
}
