package models

import "gorm.io/gorm"

type Pattern struct {
	gorm.Model
	Name      string `gorm:"not null; type:varchar(255);"`
	Icon      string `gorm:"not null; type:varchar(255);"`
	Color     string `gorm:"not null; type:varchar(255);"`
	Type      string `gorm:"not null; type:varchar(255);"`
	ProfileID *uint
}
