package models

import "gorm.io/gorm"

type Pattern struct {
	gorm.Model
	Name        string      `gorm:"not null; type:varchar(255);"`
	Description string      `gorm:"type:text;"`
	Metadata    interface{} `gorm:"type:json;"`
	Icon        string      `gorm:"not null; type:varchar(255);"`
	Color       string      `gorm:"not null; type:varchar(255);"`
	Type        string      `gorm:"not null; type:varchar(255);"`
	FinalScore  float64     `gorm:"not null; type:float;"`
	ProfileID   *uint
}
