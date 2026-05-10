package models

import "gorm.io/gorm"

type Category struct {
	gorm.Model
	ProfileID        *uint   `gorm:"index" json:"profile_id,omitempty"`
	Type             *string `gorm:"type:varchar(255)" json:"type,omitempty"`
	Name             string  `gorm:"not null; type:varchar(255);" json:"name"`
	Icon             string  `gorm:"not null; type:varchar(255);" json:"icon"`
	Color            string  `gorm:"not null; type:varchar(255);" json:"color"`
	ParentCategoryID *uint   `json:"parent_category_id,omitempty"`
}
