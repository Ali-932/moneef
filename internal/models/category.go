package models

import (
	"gorm.io/gorm"
)

type Category struct {
	gorm.Model
	ProfileID        *uint
	Transactions     *[]Transaction `gorm:"foreignKey:CategoryID;"`
	Type             *string
	Name             string `gorm:"not null; type:varchar(255);"`
	Icon             string `gorm:"not null; type:varchar(255);"`
	Color            string `gorm:"not null; type:varchar(255);"`
	ParentCategoryID *uint
}
